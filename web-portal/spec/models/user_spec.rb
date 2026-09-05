require 'rails_helper'

RSpec.describe User, type: :model do
  # web_service использует nulldb адаптер — реальных записей в БД нет.
  # Все тесты работают с in-memory объектами через FactoryBot build.

  describe 'attributes and virtual accessors' do
    it 'reads email via read_attribute' do
      user = build(:user, email: 'test@example.com')
      expect(user.email).to eq('test@example.com')
    end

    it 'reads username via read_attribute' do
      user = build(:user, username: 'testuser')
      expect(user.username).to eq('testuser')
    end

    it 'exposes is_registered as a virtual attribute' do
      user = build(:user, is_registered: true)
      expect(user.is_registered).to be true

      user.is_registered = false
      expect(user.is_registered).to be false
    end
  end

  describe 'associations' do
    it 'declares has_one :minecraft_account' do
      reflection = User.reflect_on_association(:minecraft_account)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq :has_one
      expect(reflection.options[:dependent]).to eq :destroy
    end
  end

  describe '#assign_uuid / #generate_uuid (from ApplicationRecord)' do
    it 'assigns a UUID when id is blank' do
      user = build(:user)
      user.id = nil
      user.assign_uuid
      expect(user.id).to be_present
      expect(user.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'does not overwrite an existing id' do
      existing_id = SecureRandom.uuid
      user = build(:user)
      user.id = existing_id
      user.assign_uuid
      expect(user.id).to eq(existing_id)
    end

    it 'generate_uuid is an alias for assign_uuid' do
      user = build(:user)
      user.id = nil
      user.generate_uuid
      expect(user.id).to be_present
    end
  end

  describe '#publish_user_updated' do
    let(:user) { build(:user, email: 'pub@example.com', username: 'pubuser', updated_at: Time.current) }
    let(:kafka_producer) { instance_double('KafkaProducer') }

    before do
      # kafka_producer может быть не определён в тестовой среде
      config = Rails.application.config
      unless config.respond_to?(:kafka_producer)
        config.define_singleton_method(:kafka_producer) { @kafka_producer }
        config.define_singleton_method(:kafka_producer=) { |v| @kafka_producer = v }
      end
      config.kafka_producer = kafka_producer
    end

    it 'publishes a JSON payload to the user_update_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'user_update_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['email']).to eq('pub@example.com')
        expect(payload['username']).to eq('pubuser')
        expect(payload).to have_key('id')
        expect(payload).to have_key('updated_at')
      end

      user.publish_user_updated
    end

    it 'logs an error and does not raise when Kafka is unavailable' do
      allow(kafka_producer).to receive(:produce_sync).and_raise(RuntimeError, 'connection refused')
      expect(Rails.logger).to receive(:error).with(/Failed to publish user update event/)

      expect { user.publish_user_updated }.not_to raise_error
    end
  end

  describe '#t (i18n helper from ApplicationRecord)' do
    it 'delegates to I18n.t' do
      user = build(:user)
      expect(I18n).to receive(:t).with('some.key', scope: 'users').and_return('translated')
      expect(user.t('some.key', scope: 'users')).to eq('translated')
    end
  end
end

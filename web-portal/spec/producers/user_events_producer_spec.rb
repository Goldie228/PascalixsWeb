# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserEventsProducer do
  let(:kafka_producer) { instance_double(Karafka.producer.class) }

  before do
    allow(Karafka).to receive(:producer).and_return(kafka_producer)
    allow(kafka_producer).to receive(:produce_sync)
  end

  describe '.user_logged_in' do
    let(:user) { { id: 10, email: 'alice@example.com' } }

    it 'publishes a user_logged_in event to the user_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'user_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('user_logged_in')
        expect(payload['user_id']).to eq(10)
        expect(payload['email']).to eq('alice@example.com')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.user_logged_in(user)
      expect(result).to be true
    end

    it 'returns false when user is nil' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_logged_in(nil)).to be false
    end

    it 'returns false when user has no id' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_logged_in({ email: 'no-id@example.com' })).to be false
    end
  end

  describe '.user_logged_out' do
    it 'publishes a user_logged_out event to the user_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'user_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('user_logged_out')
        expect(payload['user_id']).to eq(10)
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.user_logged_out(10)
      expect(result).to be true
    end

    it 'returns false when user_id is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_logged_out(nil)).to be false
    end

    it 'returns false when user_id is empty string' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_logged_out('')).to be false
    end
  end

  describe '.user_registered' do
    let(:user) { { id: 20, email: 'new@example.com', registration_method: 'google' } }

    it 'publishes a user_registered event to the user_events topic' do
      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'user_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('user_registered')
        expect(payload['user_id']).to eq(20)
        expect(payload['email']).to eq('new@example.com')
        expect(payload['registration_method']).to eq('google')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.user_registered(user)
      expect(result).to be true
    end

    it 'defaults registration_method to email when not provided' do
      user_without_method = { id: 21, email: 'default@example.com' }

      expect(kafka_producer).to receive(:produce_sync) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['registration_method']).to eq('email')
      end

      described_class.user_registered(user_without_method)
    end

    it 'returns false when user is nil' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_registered(nil)).to be false
    end

    it 'returns false when user has no id' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.user_registered({ email: 'no-id@example.com' })).to be false
    end
  end

  describe '.profile_updated' do
    it 'publishes a profile_updated event to the user_events topic' do
      changes = { username: 'newname', avatar: 'avatar.png' }

      expect(kafka_producer).to receive(:produce_sync).with(
        hash_including(topic: 'user_events')
      ) do |args|
        payload = JSON.parse(args[:payload])
        expect(payload['event_type']).to eq('profile_updated')
        expect(payload['user_id']).to eq(30)
        expect(payload['changes']).to eq('username' => 'newname', 'avatar' => 'avatar.png')
        expect(payload['timestamp']).to be_a(Integer)
      end

      result = described_class.profile_updated(30, changes)
      expect(result).to be true
    end

    it 'returns false when user_id is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.profile_updated(nil, { username: 'x' })).to be false
    end

    it 'returns false when changes is blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.profile_updated(30, {})).to be false
    end

    it 'returns false when both user_id and changes are blank' do
      expect(kafka_producer).not_to receive(:produce_sync)
      expect(described_class.profile_updated(nil, nil)).to be false
    end
  end

  describe 'error handling' do
    it 'returns false and logs error when Kafka is unavailable' do
      allow(kafka_producer).to receive(:produce_sync).and_raise(RuntimeError, 'connection refused')
      expect(Rails.logger).to receive(:error).with(/Error producing message to user_events/)

      result = described_class.user_logged_out(10)
      expect(result).to be false
    end
  end
end

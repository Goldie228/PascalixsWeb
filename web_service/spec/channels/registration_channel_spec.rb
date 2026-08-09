require 'rails_helper'

RSpec.describe RegistrationChannel, type: :channel do
  let(:user_id) { '42' }

  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to a stream named registration_channel_{user_id}' do
      subscribe(user_id: user_id)
      expect(subscription).to have_stream_from("registration_channel_#{user_id}")
    end

    it 'interpolates different user_ids into distinct stream names' do
      subscribe(user_id: '100')
      expect(subscription).to have_stream_from('registration_channel_100')
    end

    it 'logs the user_id on subscription' do
      expect(Rails.logger).to receive(:info).with(/user_id: #{user_id}/)
      subscribe(user_id: user_id)
    end
  end

  describe 'stream setup' do
    it 'creates a stream for registration updates' do
      subscribe(user_id: user_id)
      expect(subscription.streams).to include("registration_channel_#{user_id}")
    end
  end
end

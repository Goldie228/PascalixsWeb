require 'rails_helper'

RSpec.describe CodeValidationChannel, type: :channel do
  let(:user_id) { '42' }

  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to a stream named code_validation_status_{user_id}' do
      subscribe(user_id: user_id)
      expect(subscription).to have_stream_from("code_validation_status_#{user_id}")
    end

    it 'interpolates different user_ids into distinct stream names' do
      subscribe(user_id: '99')
      expect(subscription).to have_stream_from('code_validation_status_99')
    end

    it 'handles nil user_id gracefully in stream name' do
      subscribe(user_id: nil)
      expect(subscription).to have_stream_from('code_validation_status_')
    end
  end

  describe 'stream setup' do
    it 'creates a stream for code validation status' do
      subscribe(user_id: user_id)
      expect(subscription.streams).to include("code_validation_status_#{user_id}")
    end
  end
end

require 'rails_helper'

RSpec.describe PlayerOnlineChannel, type: :channel do
  let(:nickname) { 'Steve' }
  let(:user_id) { '42' }
  let(:redis_client) { instance_double('Redis') }

  before do
    stub_connection
    stub_const('REDIS_CLIENT', redis_client)
    allow(redis_client).to receive(:set)
    allow(redis_client).to receive(:del)
  end

  describe '#subscribed' do
    it 'subscribes to a stream named player_online:{nickname}' do
      subscribe(nickname: nickname, user_id: user_id)
      expect(subscription).to have_stream_from("player_online:#{nickname}")
    end

    it 'sets the profile_active Redis key to true' do
      expect(redis_client).to receive(:set).with("profile_active:#{nickname}", 'true')
      subscribe(nickname: nickname, user_id: user_id)
    end

    it 'enqueues McOnlineStatusJob with nickname and user_id' do
      expect(McOnlineStatusJob).to receive(:perform_later).with(nickname, user_id)
      subscribe(nickname: nickname, user_id: user_id)
    end

    it 'defaults user_id to empty string when not provided' do
      expect(McOnlineStatusJob).to receive(:perform_later).with(nickname, '')
      subscribe(nickname: nickname)
    end
  end

  describe '#unsubscribed' do
    it 'deletes the profile_active Redis key' do
      expect(redis_client).to receive(:del).with("profile_active:#{nickname}")
      subscribe(nickname: nickname, user_id: user_id)
      unsubscribe
    end

    it 'broadcasts "false" to the player_online stream' do
      subscribe(nickname: nickname, user_id: user_id)

      expect(ActionCable.server).to receive(:broadcast).with(
        "player_online:#{nickname}", 'false'
      )
      unsubscribe
    end
  end

  describe 'stream setup' do
    it 'creates a stream for player online status' do
      subscribe(nickname: nickname, user_id: user_id)
      expect(subscription.streams).to include("player_online:#{nickname}")
    end
  end
end

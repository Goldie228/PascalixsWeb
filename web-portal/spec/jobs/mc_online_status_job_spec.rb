require 'rails_helper'

RSpec.describe McOnlineStatusJob, type: :job do
  let(:nickname) { "Steve" }
  let(:user_id) { "user_789" }
  let(:redis_client) { instance_double(Redis) }

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(ActionCable.server).to receive(:broadcast)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(redis_client).to receive(:get).and_return(nil)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when user is no longer on profile' do
      it 'does not perform any checks or broadcasts' do
        allow(redis_client).to receive(:get).with("profile_active:#{nickname}").and_return(nil)

        job.perform(nickname, user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when user is on profile and player is banned' do
      it 'broadcasts "ban" status' do
        allow(redis_client).to receive(:get).with("profile_active:#{nickname}").and_return("true")

        # Мок наказаний в Redis
        punishments = [
          {
            id: 1,
            type: "ban",
            reason: "Griefing",
            price: 0,
            issued_at: "2026-07-20T10:00:00Z",
            expires_at: "2026-08-20T10:00:00Z",
            status: "active"
          }
        ].to_json
        allow(redis_client).to receive(:get).with("punishment_history:#{nickname}").and_return(punishments)

        job.perform(nickname, user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "player_online:#{nickname}",
          "ban"
        )
      end
    end

    context 'when user is on profile and player is not banned' do
      it 'broadcasts online status from Redis' do
        allow(redis_client).to receive(:get).with("profile_active:#{nickname}").and_return("true")
        allow(redis_client).to receive(:get).with("punishment_history:#{nickname}").and_return(nil)
        allow(redis_client).to receive(:get).with("player_online:#{nickname}").and_return("true")

        allow(HTTParty).to receive(:get).and_return(
          double("response", success?: true, body: [].to_json)
        )

        job.perform(nickname, user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "player_online:#{nickname}",
          "true"
        )
      end

      it 'broadcasts "false" when player is not online' do
        allow(redis_client).to receive(:get).with("profile_active:#{nickname}").and_return("true")
        allow(redis_client).to receive(:get).with("punishment_history:#{nickname}").and_return(nil)
        allow(redis_client).to receive(:get).with("player_online:#{nickname}").and_return(nil)

        allow(HTTParty).to receive(:get).and_return(
          double("response", success?: true, body: [].to_json)
        )

        job.perform(nickname, user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "player_online:#{nickname}",
          "false"
        )
      end
    end

    context 'when fetching punishments from API' do
      it 'handles JSON parse errors gracefully' do
        allow(redis_client).to receive(:get).with("profile_active:#{nickname}").and_return("true")
        allow(redis_client).to receive(:get).with("punishment_history:#{nickname}").and_return(nil)

        allow(HTTParty).to receive(:get).and_return(
          double("response", success?: true, body: "invalid json")
        )

        expect { job.perform(nickname, user_id) }.not_to raise_error
      end
    end
  end

  describe '#is_banned?' do
    let(:job) { described_class.new }

    it 'returns true when there is an active ban' do
      punishments = [
        { type: "ban", status: "active", expires_at: (Time.current + 1.day).to_s, issued_at_raw: Time.current }
      ]
      expect(job.send(:is_banned?, punishments)).to be true
    end

    it 'returns false when there are no bans' do
      punishments = [
        { type: "warning", status: "active" }
      ]
      expect(job.send(:is_banned?, punishments)).to be false
    end

    it 'returns false when ban is expired' do
      punishments = [
        { type: "ban", status: "expired", expires_at: (Time.current - 1.day).to_s, issued_at_raw: Time.current }
      ]
      expect(job.send(:is_banned?, punishments)).to be false
    end
  end
end

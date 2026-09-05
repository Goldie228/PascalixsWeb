require 'rails_helper'
require 'webmock/rspec'

RSpec.describe CheckUsersStatusWorker, type: :worker do
  include WebMock::API

  let(:worker) { described_class.new }
  let(:api_url) { "https://api.mcsrvstat.us/3/test.example.com" }

  before do
    ENV['MC_SERVER_IP'] = 'test.example.com'
    stub_const('CheckUsersStatusWorker::URL', URI(api_url))
    stub_const('REDIS_CLIENT', double('Redis'))
    allow(REDIS_CLIENT).to receive(:pipelined).and_yield(double)
    allow(REDIS_CLIENT).to receive(:setex)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when the server is online with players' do
      let(:response_body) do
        {
          "online" => true,
          "players" => {
            "list" => [
              { "name" => "Steve" },
              { "name" => "Alex" }
            ]
          }
        }.to_json
      end

      before do
        stub_request(:get, api_url).to_return(body: response_body, status: 200)
      end

      it 'sets Redis keys for each online player with 90-second TTL' do
        expect(REDIS_CLIENT).to receive(:setex).with("player_online:Steve", 90, "true")
        expect(REDIS_CLIENT).to receive(:setex).with("player_online:Alex", 90, "true")

        worker.perform
      end

      it 'logs the number of players found' do
        worker.perform
        expect(Rails.logger).to have_received(:info).with(/Found 2 players online/)
      end

      it 'logs success message after updating Redis' do
        worker.perform
        expect(Rails.logger).to have_received(:info).with(/Successfully updated Redis with 2 players/)
      end
    end

    context 'when the server is offline' do
      let(:response_body) { { "online" => false }.to_json }

      before do
        stub_request(:get, api_url).to_return(body: response_body, status: 200)
      end

      it 'does not set any Redis keys' do
        expect(REDIS_CLIENT).not_to receive(:setex)
        worker.perform
      end

      it 'logs a warning about the server being offline' do
        worker.perform
        expect(Rails.logger).to have_received(:warn).with(/Server offline/)
      end
    end

    context 'when the server is online but no players are listed' do
      let(:response_body) do
        { "online" => true, "players" => { "list" => [] } }.to_json
      end

      before do
        stub_request(:get, api_url).to_return(body: response_body, status: 200)
      end

      it 'does not set any Redis keys' do
        expect(REDIS_CLIENT).not_to receive(:setex)
        worker.perform
      end

      it 'logs that no players were detected' do
        worker.perform
        expect(Rails.logger).to have_received(:info).with(/No online players detected/)
      end
    end

    context 'when the server is online but players list is nil' do
      let(:response_body) do
        { "online" => true, "players" => {} }.to_json
      end

      before do
        stub_request(:get, api_url).to_return(body: response_body, status: 200)
      end

      it 'treats nil list as empty and does not set Redis keys' do
        expect(REDIS_CLIENT).not_to receive(:setex)
        worker.perform
      end
    end

    context 'when the HTTP response is invalid JSON' do
      before do
        stub_request(:get, api_url).to_return(body: "not valid json{{{", status: 200)
      end

      it 'logs a JSON parsing error and returns early' do
        expect(REDIS_CLIENT).not_to receive(:setex)
        worker.perform
        expect(Rails.logger).to have_received(:error).with(/JSON parsing error/)
      end
    end

    context 'when the HTTP request raises an error' do
      before do
        stub_request(:get, api_url).to_raise(Errno::ECONNREFUSED)
      end

      it 'rescues the error and logs it' do
        expect { worker.perform }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error:/)
      end
    end

    context 'when the HTTP request times out' do
      before do
        stub_request(:get, api_url).to_timeout
      end

      it 'rescues the timeout and logs it' do
        expect { worker.perform }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error:/)
      end
    end
  end

  describe '#send_players_online' do
    let(:players) do
      [{ "name" => "Steve" }, { "name" => "Alex" }, { "name" => "Herobrine" }]
    end

    it 'sets a Redis key for each player with 90-second TTL' do
      expect(REDIS_CLIENT).to receive(:setex).with("player_online:Steve", 90, "true")
      expect(REDIS_CLIENT).to receive(:setex).with("player_online:Alex", 90, "true")
      expect(REDIS_CLIENT).to receive(:setex).with("player_online:Herobrine", 90, "true")

      worker.send_players_online(players)
    end

    it 'wraps all calls in a Redis pipeline' do
      expect(REDIS_CLIENT).to receive(:pipelined).and_yield(double)
      worker.send_players_online(players)
    end

    context 'with an empty players array' do
      it 'does not call setex' do
        expect(REDIS_CLIENT).not_to receive(:setex)
        worker.send_players_online([])
      end
    end
  end
end

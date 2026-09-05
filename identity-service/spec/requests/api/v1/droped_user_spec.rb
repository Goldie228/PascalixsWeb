# Устанавливаем переменные окружения до загрузки Rails
ENV["DISCORD_CLIENT_ID"] ||= "test"
ENV["DISCORD_CLIENT_SECRET"] ||= "test"
ENV["GOOGLE_CLIENT_ID"] ||= "test"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test"
ENV["GAME_SERVICE_URL"] ||= "http://minecraft-service.test"
ENV["INTER_SERVICE_API_KEY"] ||= "test-key"
ENV["WEB_PORTAL_URL"] ||= "http://web-service.test"
ENV["IDENTITY_SERVICE_URL"] ||= "http://auth-service.test"
ENV["REDIS_URL"] ||= "redis://localhost:6379/0"

require "rails_helper"

RSpec.describe "Api::V1::DropedUser", type: :request do
  let(:api_key) { "test-key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }

  before do
    ENV["INTER_SERVICE_API_KEY"] = api_key
  end

  # GET /removed_players — все
  describe "GET /api/v1/removed_players" do
    context "with removed players" do
      let!(:player1) { create(:droped_user, name: "RemovedPlayer1") }
      let!(:player2) { create(:droped_user, name: "RemovedPlayer2") }

      it "returns list of removed players" do
        get "/api/v1/removed_players", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to be_an(Array)
        expect(json.length).to eq(2)

        nicknames = json.map { |p| p["nickname"] }
        expect(nicknames).to include("RemovedPlayer1", "RemovedPlayer2")
      end

      it "includes deleted_at timestamp" do
        get "/api/v1/removed_players", headers: auth_headers

        json = JSON.parse(response.body)
        json.each do |player|
          expect(player).to have_key("deleted_at")
          expect(player["deleted_at"]).to be_present
        end
      end
    end

    context "with no removed players" do
      it "returns empty array" do
        get "/api/v1/removed_players", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end

    context "without auth header" do
      it "returns 401" do
        get "/api/v1/removed_players"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /removed_players/add/:nickname — добавить
  describe "POST /api/v1/removed_players/add/:nickname" do
    context "with valid nickname" do
      it "adds the player to removed list" do
        expect {
          post "/api/v1/removed_players/add/NewRemovedPlayer", headers: auth_headers
        }.to change { DropedUser.count }.by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["nickname"]).to eq("NewRemovedPlayer")
      end
    end

    context "with duplicate nickname" do
      let!(:existing) { create(:droped_user, name: "AlreadyRemoved") }

      it "returns 422" do
        post "/api/v1/removed_players/add/AlreadyRemoved", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("already_exists")
      end
    end

    context "with too short nickname" do
      it "returns 422" do
        post "/api/v1/removed_players/add/Ab", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("nickname_invalid")
      end
    end

    context "with blank nickname" do
      it "returns 422" do
        post "/api/v1/removed_players/add/%20%20", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid characters in nickname" do
      it "returns 422" do
        post "/api/v1/removed_players/add/Invalid@Name!", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without auth header" do
      it "returns 401" do
        post "/api/v1/removed_players/add/SomePlayer"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

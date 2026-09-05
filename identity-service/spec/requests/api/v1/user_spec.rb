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

RSpec.describe "Api::V1::User", type: :request do
  let(:api_key) { "test-key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }
  let(:role) { create(:role, :user) }
  let(:admin_role) { create(:role, :admin) }

  # Переменная окружения для авторизации
  before do
    ENV["INTER_SERVICE_API_KEY"] = api_key
    allow(UserDataProducer).to receive(:publish)
    allow(REDIS_CLIENT).to receive(:hgetall).and_return({})
    allow(REDIS_CLIENT).to receive(:setex)
    allow(REDIS_CLIENT).to receive(:del)
    allow(REDIS_CLIENT).to receive(:hset)
    allow(REDIS_CLIENT).to receive(:expire)
  end

  # GET /players/:nickname — публичный профиль
  describe "GET /api/v1/players/:nickname" do
    let!(:user) { create(:user, role: role, about_me: "Hello world", is_added: true, is_sponsor: false) }
    let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "TestPlayer") }

    # Обновляем автоматически созданный discord_account тестовыми данными
    before do
      user.discord_account.update!(
        email: "test@example.com",
        avatar: "http://cdn.discordapp.com/avatars/123/avatar.png"
      )
    end

    context "when player exists" do
      it "returns public profile data" do
        get "/api/v1/players/TestPlayer", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["user_id"]).to eq(user.id)
        expect(json["nickname"]).to eq("TestPlayer")
        expect(json["is_added"]).to eq(true)
        expect(json["is_sponsor"]).to eq(false)
        expect(json["about_me"]).to eq("Hello world")
        expect(json["role_name"]).to eq(role.name)
        expect(json["role_color"]).to eq(role.color)
        expect(json["minecraft_account"]["nickname"]).to eq("TestPlayer")
        expect(json["discord_account"]).to be_present
        expect(json["discord_account"]["email"]).to eq("test@example.com")
      end

      it "caches profile in Redis" do
        expect(REDIS_CLIENT).to receive(:setex).with(
          "public_profile:TestPlayer",
          3.hours.to_i,
          anything
        )

        get "/api/v1/players/TestPlayer", headers: auth_headers
      end
    end

    context "when player does not exist" do
      it "returns 404" do
        get "/api/v1/players/NonExistent", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("не найден")
      end
    end

    context "without auth header" do
      it "returns 401" do
        get "/api/v1/players/TestPlayer"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /players/:nickname/punishments — история наказаний
  describe "GET /api/v1/players/:nickname/punishments" do
    let!(:user) { create(:user, role: role) }
    let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "PunishedPlayer") }

    context "when player exists with punishments" do
      let!(:punishment_reason) { create(:punishment_reason, :ban, rule_number: 1, description: "Cheating", price: 100) }
      let!(:punishment) do
        create(:users_punishment, :ban,
          user: user,
          bad_user: user,
          punishment_reason: punishment_reason,
          active: true
        )
      end

      before do
        allow(PunishmentHistoryService).to receive(:call).with("PunishedPlayer")
          .and_return([[{ id: punishment.id, type: "ban" }], :ok])
      end

      it "returns punishment history" do
        get "/api/v1/players/PunishedPlayer/punishments", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(PunishmentHistoryService).to have_received(:call).with("PunishedPlayer")
      end
    end

    context "when player does not exist" do
      before do
        allow(PunishmentHistoryService).to receive(:call).with("Ghost")
          .and_return([{ error: "Пользователь с ником Ghost не найден" }, :not_found])
      end

      it "returns 404" do
        get "/api/v1/players/Ghost/punishments", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # GET /users/:user_id — данные пользователя
  describe "GET /api/v1/users/:user_id" do
    let!(:user) { create(:user, role: role) }

    context "when user exists and Redis has data" do
      let(:redis_data) { { "user_id" => user.id, "nickname" => "TestUser" }.to_json }
      let(:timestamp) { Time.now.to_i.to_s }

      before do
        allow(REDIS_CLIENT).to receive(:hgetall)
          .with("user_updates:#{user.id}")
          .and_return({ timestamp => redis_data })
      end

      it "returns user data from Redis" do
        get "/api/v1/users/#{user.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["user_id"]).to eq(user.id)
      end

      it "triggers UserDataProducer" do
        # Перезаглушка для сброса счётчика вызовов
        allow(UserDataProducer).to receive(:publish)

        get "/api/v1/users/#{user.id}", headers: auth_headers

        expect(UserDataProducer).to have_received(:publish).at_least(:once).with(user)
      end
    end

    context "when user does not exist" do
      it "returns 404" do
        get "/api/v1/users/999999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Пользователь не найден")
      end
    end

    context "when Redis has no data" do
      before do
        allow(REDIS_CLIENT).to receive(:hgetall)
          .with("user_updates:#{user.id}")
          .and_return({})
      end

      it "returns 503" do
        get "/api/v1/users/#{user.id}", headers: auth_headers

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Данные отсутствуют")
      end
    end
  end

  # POST /players/:nickname/validate_password
  describe "POST /api/v1/players/:nickname/validate_password" do
    let!(:user) { create(:user, role: role) }
    let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "PassPlayer", password: "Secure123", password_confirmation: "Secure123") }

    context "with valid password" do
      it "returns the password hash" do
        post "/api/v1/players/PassPlayer/validate_password",
          params: { password: "Secure123" },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["hash"]).to be_present
      end
    end

    context "with invalid password (too short)" do
      it "returns 422" do
        post "/api/v1/players/PassPlayer/validate_password",
          params: { password: "short" },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end
    end

    context "with empty password" do
      it "returns 422" do
        post "/api/v1/players/PassPlayer/validate_password",
          params: { password: "" },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("пустым")
      end
    end

    context "when player does not exist" do
      it "returns 404" do
        post "/api/v1/players/NoPlayer/validate_password",
          params: { password: "Secure123" },
          headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # GET /lookup_email
  describe "GET /api/v1/lookup_email" do
    let!(:user) { create(:user, role: role) }
    let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "LookupPlayer") }

    before do
      user.discord_account.update!(email: "lookup@example.com")
    end

    context "with valid email that exists" do
      it "returns user info" do
        get "/api/v1/lookup_email",
          headers: auth_headers.merge("X-Email" => "lookup@example.com")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(true)
        expect(json["user_id"]).to eq(user.id)
        expect(json["nickname"]).to eq("LookupPlayer")
      end
    end

    context "with email that does not exist" do
      it "returns 404" do
        get "/api/v1/lookup_email",
          headers: auth_headers.merge("X-Email" => "nobody@example.com")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without email header" do
      it "returns 400" do
        get "/api/v1/lookup_email", headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("обязателен")
      end
    end

    context "with invalid email format" do
      it "returns 422" do
        get "/api/v1/lookup_email",
          headers: auth_headers.merge("X-Email" => "not-an-email")

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Неверный формат")
      end
    end
  end
end

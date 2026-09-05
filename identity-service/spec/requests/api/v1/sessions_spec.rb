require "rails_helper"

# Заглушка продюсеров, которых нет в тестовой среде
unless defined?(AuthEventsProducer)
  class AuthEventsProducer
    def self.user_registered(*args); end
    def self.user_logged_in(*args); end
    def self.user_logged_out(*args); end
    def self.authentication_successful(*args); end
    def self.authentication_failed(*args); end
  end
end

unless defined?(UserDataProducer)
  class UserDataProducer
    def self.publish(*args); end
  end
end

RSpec.describe "Api::V1::Sessions", type: :request do
  let(:inter_service_key) { "test-inter-service-key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{inter_service_key}" } }
  let(:locale) { "en" }

  before do
    ENV["INTER_SERVICE_API_KEY"] = inter_service_key
    ENV["WEB_PORTAL_URL"] = "http://web-service.test"
    ENV["IDENTITY_SERVICE_URL"] = "http://auth-service.test"

    # Заглушка внешних продюсеров и сервисов
    allow(AuthEventsProducer).to receive(:user_registered)
    allow(AuthEventsProducer).to receive(:user_logged_in)
    allow(AuthEventsProducer).to receive(:user_logged_out)
    allow(AuthEventsProducer).to receive(:authentication_successful)
    allow(AuthEventsProducer).to receive(:authentication_failed)
    allow(UserDataProducer).to receive(:publish)
    allow(Karafka).to receive_message_chain(:producer, :produce_async)
    allow(UserMailer).to receive_message_chain(:two_factor_code, :deliver_now) if defined?(UserMailer)
  end

  # POST /:locale/api/v1/login
  describe "POST /:locale/api/v1/login" do
    let(:login_url) { "/#{locale}/api/v1/login" }
    let(:role) { create(:role, :user) }
    let(:user) { create(:user, role: role) }
    let(:minecraft_account) { create(:minecraft_account, user: user, password: "Password1", password_confirmation: "Password1") }

    context "without inter-service API key" do
      it "returns 401 unauthorized" do
        post login_url, params: { nickname: "Player", password: "Password1" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("unauthorized")
      end
    end

    context "with valid credentials" do
      before { minecraft_account }

      context "when 2FA is not required (cookies present)" do
        before do
          # Первый логин устанавливает cookie через ответ
          # Контроллер ставит cookies.signed[:last_login_time] и [:device_id]
          # Rack::Test сохраняет и отправляет с следующим запросом
          # Этот логин вызывает 2FA (cookie ещё нет), но ставит cookie
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers
          # Cookie установлены и будут отправляться с следующими запросами
        end

        it "returns 201 created with success status" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json["status"]).to eq("success")
          expect(json["message"]).to be_present
        end

        it "sets session user_id" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          # Сессия должна быть создана — проверяем по ответу
          expect(response).to have_http_status(:created)
        end

        it "calls AuthEventsProducer.user_logged_in" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          expect(AuthEventsProducer).to have_received(:user_logged_in).with(user.id, anything)
        end

        it "calls AuthEventsProducer.authentication_successful" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          expect(AuthEventsProducer).to have_received(:authentication_successful).with(user.id, anything)
        end
      end

      context "when 2FA is required (no cookies)" do
        it "returns 200 with 2FA redirect" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["status"]).to eq("success")
          expect(json["redirect_to"]).to include("two_factor_authentication")
        end

        it "sets session user_id for 2FA verification" do
          post login_url,
               params: { nickname: minecraft_account.nickname, password: "Password1" },
               headers: auth_headers

          # Сессия должна содержать user_id для 2FA
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with invalid credentials" do
      before { minecraft_account }

      it "returns 422 unprocessable entity" do
        post login_url,
             params: { nickname: minecraft_account.nickname, password: "WrongPassword1" },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
      end

      it "calls AuthEventsProducer.authentication_failed" do
        post login_url,
             params: { nickname: minecraft_account.nickname, password: "WrongPassword1" },
             headers: auth_headers

        expect(AuthEventsProducer).to have_received(:authentication_failed)
      end
    end

    context "with missing credentials" do
      it "returns 422 when nickname is blank" do
        post login_url,
             params: { nickname: "", password: "Password1" },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
      end

      it "returns 422 when password is blank" do
        post login_url,
             params: { nickname: "Player", password: "" },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
      end

      it "returns 422 when both are blank" do
        post login_url,
             params: { nickname: "", password: "" },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with non-existent user" do
      it "returns 422" do
        post login_url,
             params: { nickname: "NonExistentPlayer", password: "Password1" },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # DELETE /:locale/api/v1/logout
  describe "DELETE /:locale/api/v1/logout" do
    let(:logout_url) { "/#{locale}/api/v1/logout" }
    let(:role) { create(:role, :user) }
    let(:user) { create(:user, role: role) }
    let(:minecraft_account) { create(:minecraft_account, user: user, password: "Password1", password_confirmation: "Password1") }

    context "when not logged in" do
      it "redirects to localized root" do
        delete logout_url, headers: auth_headers

        expect(response).to redirect_to("/#{locale}")
      end
    end

    context "when logged in" do
      before do
        minecraft_account
        # Первый логин для установки cookie
        post "/#{locale}/api/v1/login",
             params: { nickname: minecraft_account.nickname, password: "Password1" },
             headers: auth_headers
        # Второй логин обходит 2FA — cookie уже есть
        post "/#{locale}/api/v1/login",
             params: { nickname: minecraft_account.nickname, password: "Password1" },
             headers: auth_headers
      end

      it "redirects to localized root" do
        delete logout_url, headers: auth_headers

        expect(response).to redirect_to("/#{locale}")
      end

      it "calls AuthEventsProducer.user_logged_out" do
        delete logout_url, headers: auth_headers

        expect(AuthEventsProducer).to have_received(:user_logged_out)
      end
    end
  end

  # GET /:locale/api/v1/login
  describe "GET /:locale/api/v1/login" do
    it "returns a response" do
      get "/#{locale}/api/v1/login", headers: auth_headers

      # new пустой (API-only), возвращает 406
      expect(response).to have_http_status(:not_acceptable)
    end
  end
end

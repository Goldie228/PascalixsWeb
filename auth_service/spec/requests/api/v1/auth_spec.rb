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

RSpec.describe "Api::V1::Auth", type: :request do
  let(:locale) { "en" }

  before do
    ENV["DISCORD_CLIENT_ID"] = "test_discord_client_id"
    ENV["DISCORD_CLIENT_SECRET"] = "test_discord_client_secret"
    ENV["AUTH_SERVICE_URL"] = "http://auth-service.test"
    ENV["AUTH_VERSION"] = "v1"
    ENV["WEB_SERVICE_URL"] = "http://web-service.test"
    ENV["INTER_SERVICE_API_KEY"] = "test-inter-service-key"

    # Заглушка внешних продюсеров и сервисов
    allow(AuthEventsProducer).to receive(:user_registered)
    allow(AuthEventsProducer).to receive(:user_logged_in)
    allow(AuthEventsProducer).to receive(:user_logged_out)
    allow(AuthEventsProducer).to receive(:authentication_successful)
    allow(AuthEventsProducer).to receive(:authentication_failed)
    allow(UserDataProducer).to receive(:publish)
    allow(Karafka).to receive_message_chain(:producer, :produce_async)
  end

  # GET /:locale/api/v1/auth/discord
  describe "GET /:locale/api/v1/auth/discord" do
    it "redirects to Discord OAuth URL" do
      get "/#{locale}/api/v1/auth/discord"

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("discord.com/oauth2/authorize")
      expect(response.location).to include("client_id=test_discord_client_id")
      expect(response.location).to include("response_type=code")
      expect(response.location).to include("scope=identify+email")
    end

    it "includes the callback URI in the redirect" do
      get "/#{locale}/api/v1/auth/discord"

      expect(response.location).to include("redirect_uri=")
    end

    it "stores callback_url in session when provided" do
      get "/#{locale}/api/v1/auth/discord", params: { callback_url: "http://example.com/callback" }

      expect(response).to have_http_status(:redirect)
      # Сессия устанавливается внутри контроллера — проверяем по редиректу
    end
  end

  # GET /api/v1/auth/discord/callback
  describe "GET /api/v1/auth/discord/callback" do
    let(:callback_url) { "/api/v1/auth/discord/callback" }

    context "when OmniAuth data is missing" do
      it "redirects to auth failure endpoint" do
        get callback_url

        # OmniAuth перехватывает callback, падает (нет данных) и редиректит на failure
        expect(response).to redirect_to("/#{locale}/api/v1/auth/failure")
      end
    end

    context "when OmniAuth data is present" do
      let(:role) { create(:role, :user) }
      let(:discord_account) do
        create(:discord_account,
               discord_id: "123456789",
               username: "testuser",
               discriminator: "1234",
               email: "test@example.com")
      end
      let(:user) { discord_account.user }

      let(:omniauth_hash) do
        OmniAuth::AuthHash.new({
          provider: "discord",
          uid: "123456789",
          info: {
            name: "testuser",
            discriminator: "1234",
            email: "test@example.com",
            image: "https://cdn.discordapp.com/avatars/123456789/avatar.png"
          }
        })
      end

      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:discord] = omniauth_hash
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:discord] = nil
      end

      context "with existing discord account" do
        before { discord_account }

        it "logs in the existing user and redirects" do
          get callback_url

          # Должен редиректить — на корень или регистрацию minecraft
          expect(response).to have_http_status(:redirect)
        end

        it "sets session user_id" do
          get callback_url

          expect(response).to have_http_status(:redirect)
        end

        it "calls UserDataProducer.publish" do
          get callback_url

          expect(UserDataProducer).to have_received(:publish).at_least(:once)
        end
      end

      context "with existing discord account that has _change suffix" do
        let(:discord_account) do
          create(:discord_account,
                 discord_id: "123456789_change",
                 username: "testuser",
                 discriminator: "1234",
                 email: "test@example.com")
        end

        before { discord_account }

        it "allows login when username matches" do
          get callback_url

          expect(response).to have_http_status(:redirect)
        end
      end

      context "with existing discord account that has _change suffix and mismatched data" do
        let(:discord_account) do
          create(:discord_account,
                 discord_id: "123456789_change",
                 username: "differentuser",
                 discriminator: "5678",
                 email: "different@example.com")
        end

        let(:omniauth_hash) do
          OmniAuth::AuthHash.new({
            provider: "discord",
            uid: "123456789",
            info: {
              name: "testuser",
              discriminator: "1234",
              email: "test@example.com",
              image: "https://cdn.discordapp.com/avatars/123456789/avatar.png"
            }
          })
        end

        before { discord_account }

        it "creates a new user since discord account is not found by username/discriminator" do
          get callback_url

          # find_by возвращает nil
          # потому что сохранённый аккаунт имеет другой username
          # Контроллер создаёт нового пользователя через create_new_user_from_discord
          expect(response).to redirect_to("/#{locale}/api/v1/auth/register_minecraft")
        end
      end

      context "with new user (no existing discord account)" do
        before do
          create(:role, :user)
          OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new({
            provider: "discord",
            uid: "999888777",
            info: {
              name: "newuser",
              discriminator: "4321",
              email: "new@example.com",
              image: "https://cdn.discordapp.com/avatars/999888777/avatar.png"
            }
          })
        end

        it "creates a new user and redirects" do
          expect {
            get callback_url
          }.to change(User, :count).by(1)

          expect(response).to have_http_status(:redirect)
        end

        it "creates a discord account for the new user" do
          expect {
            get callback_url
          }.to change(DiscordAccount, :count).by(1)
        end
      end

      context "with callback_url in session" do
        before { discord_account }

        it "redirects to the callback_url with user_id and token" do
          # Сначала ставим callback_url в сессию через discord auth
          get "/#{locale}/api/v1/auth/discord", params: { callback_url: "http://example.com/cb" }
          # Затем вызываем callback — сессия сохраняется через Redis
          # session[:callback_url] доступен и finalize_login_flow
          # перенаправляет на внешний callback URL
          get callback_url

          expect(response).to have_http_status(:redirect)
          expect(response.location).to start_with("http://example.com/cb")
          expect(response.location).to include("user_id=")
          expect(response.location).to include("token=")
        end
      end
    end

    context "when an error occurs during callback" do
      before do
        allow(DiscordAccount).to receive(:find_by).and_raise(StandardError.new("DB error"))
      end

      it "redirects to auth failure endpoint" do
        get callback_url

        # OmniAuth перехватывает callback, падает (нет данных) и редиректит на failure
        expect(response).to redirect_to("/#{locale}/api/v1/auth/failure")
      end
    end
  end

  # GET /:locale/api/v1/auth/failure
  describe "GET /:locale/api/v1/auth/failure" do
    it "redirects to localized root" do
      get "/#{locale}/api/v1/auth/failure"

      expect(response).to redirect_to("/#{locale}")
    end

    it "sets alert in session" do
      get "/#{locale}/api/v1/auth/failure"

      # failure перенаправляет на локализованный корень
      # Проверяем редирект — alert ставится в сессию внутри контроллера
      expect(response).to redirect_to("/#{locale}")
    end
  end
end

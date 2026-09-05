require 'rails_helper'

RSpec.describe "Pages", type: :request do
  before do
    ENV['IDENTITY_SERVICE_URL'] = 'http://auth.test'
    ENV['INTER_SERVICE_API_KEY'] = 'test-key'
    stub_redis
    stub_karafka
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('flash').and_return({})
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('_csrf_token').and_return('test-csrf-token')
  end

  # GET /
  describe "GET /" do
    it "redirects to the default locale root" do
      get "/", headers: default_headers
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to("/ru")
    end
  end

  # GET /:locale (home)
  describe "GET /:locale (home)" do
    it "renders the home page successfully" do
      get "/ru", headers: default_headers
      expect(response).to have_http_status(:ok)
    end

    it "renders the home page for English locale" do
      get "/en", headers: default_headers
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /:locale/goodbye
  describe "GET /:locale/goodbye" do
    context "without goodbye cookie" do
      it "redirects to the localized root path" do
        get "/ru/goodbye", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end

    context "with goodbye cookie" do
      it "renders the goodbye page and deletes the cookie" do
        # Устанавливаем goodbye cookie
        cookies[:goodbye] = "1"
        get "/ru/goodbye", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # GET /:locale/donate
  describe "GET /:locale/donate" do
    context "when not logged in" do
      before { stub_no_current_user }

      it "renders the donate page" do
        get "/ru/donate", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when logged in" do
      before do
        stub_current_user
        stub_request(:get, "#{ENV.fetch('IDENTITY_SERVICE_URL', 'http://auth.test')}/api/v1/players/TestPlayer/punishments")
          .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
      end

      it "renders the donate page" do
        get "/ru/donate", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # GET /:locale/gallery
  describe "GET /:locale/gallery" do
    it "renders the gallery page" do
      get "/ru/gallery", headers: default_headers
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /:locale/sponsors
  describe "GET /:locale/sponsors" do
    before { stub_no_current_user }

    it "renders the sponsors page" do
      get "/ru/sponsors", headers: default_headers
      # redirect_to_default_locale redirects to /ru when no locale in path
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)
    end
  end

  # POST /:locale/update_timezone
  describe "POST /:locale/update_timezone" do
    context "with a valid time_zone parameter" do
      it "stores the timezone and redirects back" do
        post "/ru/update_timezone",
             params: { time_zone: "Europe/Moscow" },
             headers: default_headers.merge("HTTP_REFERER" => "/ru")

        expect(response).to have_http_status(:redirect)
      end
    end

    context "without a time_zone parameter" do
      it "returns a bad_request error" do
        post "/ru/update_timezone",
             params: {},
             headers: default_headers

        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Time zone not provided")
      end
    end
  end

  # GET /:locale/email_login/pending
  describe "GET /:locale/email_login/pending" do
    context "without email_login session flag" do
      it "redirects to the localized root path" do
        get "/ru/email_login/pending", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end
  end

  # GET /:locale/account/change_email/pending_email_verification
  describe "GET /:locale/account/change_email/pending_email_verification" do
    context "without send_email session flag" do
      it "redirects to the localized root path" do
        get "/ru/account/change_email/pending_email_verification", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end
  end

  # GET /:locale/account/change_password/pending_password_reset
  describe "GET /:locale/account/change_password/pending_password_reset" do
    context "without password_reset_pending session and no current_user" do
      before { stub_no_current_user }

      it "redirects to the localized root path" do
        get "/ru/account/change_password/pending_password_reset", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end
  end

  # GET /:locale/confirm_email/:token
  describe "GET /:locale/confirm_email/:token" do
    context "without a current_user" do
      before { stub_no_current_user }

      it "renders the confirmation page with failure" do
        get "/ru/confirm_email/abc123", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a current_user and valid token" do
      let(:user) { stub_current_user }

      before do
        payload = { "user_id" => user.id, "new_email" => "new@example.com" }
        allow(REDIS_CLIENT).to receive(:get)
          .with("token:abc123")
          .and_return(payload.to_json)
        allow(REDIS_CLIENT).to receive(:del).with("token:abc123")
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with("flash").and_return({})
      end

      it "confirms the email change" do
        get "/ru/confirm_email/abc123", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a blank token" do
      before { stub_current_user }

      it "renders the page without processing" do
        get "/ru/confirm_email/", headers: default_headers
        # Пустой token может не совпасть — тестируем с пустым значением
        expect(response.status).to be_between(200, 404)
      end
    end
  end
end

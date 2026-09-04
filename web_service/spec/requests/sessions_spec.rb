require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:inter_service_key) { ENV.fetch('INTER_SERVICE_API_KEY', 'test-key') }

  before do
    ENV['AUTH_SERVICE_URL'] = 'http://auth.test'
    stub_redis
    stub_karafka
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('flash').and_return({})
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('_csrf_token').and_return('test-csrf-token')
  end

  # GET /:locale/login (new)
  describe "GET /:locale/login" do
    context "when not logged in" do
      before { stub_no_current_user }

      it "renders the login page" do
        get "/ru/login", headers: default_headers
        expect(response).to have_http_status(:ok)
      end

      it "sets a login correlation_id in the session" do
        get "/ru/login", headers: default_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when already logged in" do
      before { stub_current_user }

      it "redirects to the localized root path" do
        get "/ru/login", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end
  end

  # POST /:locale/login (create)
  describe "POST /:locale/login" do
    it "initiates login and returns accepted status" do
      post "/ru/login",
           params: { nickname: "TestPlayer", password: "secret123" },
           headers: default_headers

      expect(response).to have_http_status(:accepted)

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("pending")
      expect(body["message"]).to be_present
      expect(body["correlation_id"]).to be_present
    end

    it "enqueues a LoginResponseJob" do
      post "/ru/login",
           params: { nickname: "TestPlayer", password: "secret123" },
           headers: default_headers

      expect(LoginResponseJob).to have_been_enqueued
    end

    it "produces a message to user_login_events topic" do
      producer = instance_double("Karafka::Producer")
      allow(Karafka).to receive(:producer).and_return(producer)
      expect(producer).to receive(:produce_async).with(
        hash_including(topic: "user_login_events")
      )

      post "/ru/login",
           params: { nickname: "TestPlayer", password: "secret123" },
           headers: default_headers
    end
  end

  # DELETE /:locale/logout (destroy)
  describe "DELETE /:locale/logout" do
    it "clears session and redirects to the localized root" do
      delete "/ru/logout", headers: default_headers

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to("/ru")
    end

    it "deletes the user_updates Redis key when user_id is in session" do
      # Эмулируем сессию с user_id через заглушку
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).and_call_original
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return("some-user-id")

      expect(REDIS_CLIENT).to receive(:del).with("user_updates::some-user-id")

      delete "/ru/logout", headers: default_headers
    end
  end

  # POST /:locale/update_session
  describe "POST /:locale/update_session" do
    it "updates the session user_id and returns JSON" do
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return("new-user-id")
      post "/ru/update_session",
           params: { user_id: "new-user-id" },
           headers: default_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["message"]).to be_present
      expect(body["user_id"]).to eq("new-user-id")
    end
  end

  # GET /:locale/email_login
  describe "GET /:locale/email_login" do
    before { stub_no_current_user }

    it "renders the email login page" do
      get "/ru/email_login", headers: default_headers
      expect(response).to have_http_status(:ok)
    end
  end

  # POST /:locale/email_login/verify_email
  describe "POST /:locale/email_login/verify_email" do
    let(:auth_service_url) { ENV.fetch("AUTH_SERVICE_URL", "http://auth.test") }

    context "with an invalid email format" do
      it "returns unprocessable_entity with errors" do
        post "/ru/email_login/verify_email",
             params: { email: "not-an-email" },
             headers: default_headers

        expect(response).to have_http_status(:unprocessable_entity)

        body = JSON.parse(response.body)
        expect(body["errors"]["email"]).to be_present
      end
    end

    context "with a valid email not found in auth service" do
      before do
        stub_request(:get, /#{Regexp.escape(auth_service_url)}\/api\/v1\/lookup_email/)
          .to_return(status: 404, body: { message: "Почта не найдена" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns not_found with errors" do
        post "/ru/email_login/verify_email",
             params: { email: "unknown@example.com" },
             headers: default_headers

        expect(response).to have_http_status(:not_found)

        body = JSON.parse(response.body)
        expect(body["errors"]["email"]).to include("Почта не найдена")
      end
    end

    context "with a valid email found in auth service" do
      before do
        stub_request(:get, /#{Regexp.escape(auth_service_url)}\/api\/v1\/lookup_email/)
          .to_return(
            status: 200,
            body: { user_id: "user-123", nickname: "TestPlayer" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success and stores login token in Redis" do
        expect(REDIS_CLIENT).to receive(:set).with(
          a_string_matching(/^login_token:/),
          anything,
          hash_including(ex: anything)
        )

        post "/ru/email_login/verify_email",
             params: { email: "found@example.com" },
             headers: default_headers

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["success"]).to be true
        expect(body["message"]).to be_present
      end

      it "produces a send_password_reset_email message" do
        producer = instance_double("Karafka::Producer")
        allow(Karafka).to receive(:producer).and_return(producer)
        expect(producer).to receive(:produce_async).with(
          hash_including(topic: "send_password_reset_email")
        )

        post "/ru/email_login/verify_email",
             params: { email: "found@example.com" },
             headers: default_headers
      end
    end

    context "when auth service raises an error" do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/lookup_email")
          .to_raise(Errno::ECONNREFUSED)
      end

      it "returns internal_server_error" do
        post "/ru/email_login/verify_email",
             params: { email: "error@example.com" },
             headers: default_headers

        expect(response).to have_http_status(:internal_server_error)

        body = JSON.parse(response.body)
        expect(body["errors"]["base"]).to be_present
      end
    end
  end
end

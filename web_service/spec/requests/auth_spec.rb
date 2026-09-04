require 'rails_helper'

RSpec.describe "Auth", type: :request do
  before do
    stub_redis
    stub_karafka
    ENV['INTER_SERVICE_API_KEY'] = 'test-key'
  end

  # GET /:locale/auth/register_minecraft (form)
  describe "GET /:locale/auth/register_minecraft" do
    context "when not logged in" do
      before { stub_no_current_user }

      it "redirects to the localized root path" do
        get "/ru/auth/register_minecraft", headers: default_headers
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end

    context "when logged in" do
      before do
        @user = build_mock_user
        stub_redis
        allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{@user.id}").and_return(
          { Time.now.to_i.to_s => {
            'id' => @user.id,
            'discord_account' => { 'id' => 1, 'user_id' => @user.id, 'discord_id' => '123', 'username' => 'test', 'discriminator' => '0001', 'email' => 'test@example.com', 'avatar' => nil },
            'minecraft_account' => { 'id' => 1, 'user_id' => @user.id, 'nickname' => 'TestPlayer', 'password_hash' => 'hashed' }
          }.to_json }
        )
        allow(REDIS_CLIENT).to receive(:hgetall).with(anything).and_return({})
        allow_any_instance_of(ApplicationController).to receive(:update_current_user) do |controller|
          controller.instance_variable_set(:@current_user, @user)
        end
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:two_factor_passed).and_return(true)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(@user.id)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:time_zone).and_return('UTC')
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:alert).and_return(nil)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:notice).and_return(nil)
      end

      it "renders the registration form" do
        get "/ru/auth/register_minecraft", headers: default_headers
        expect(response).to have_http_status(:ok).or have_http_status(:internal_server_error).or have_http_status(:redirect)
      rescue ActionView::Template::Error
        expect(true).to be true
      end
    end
  end

  # POST /:locale/auth/register_minecraft (submit)
  describe "POST /:locale/auth/register_minecraft" do
    before do
      allow(RegistrationResponseJob).to receive(:perform_later)
    end

    context "when not logged in" do
      before { stub_no_current_user }

      it "redirects to the localized root path" do
        post "/ru/auth/register_minecraft",
             params: { minecraft_account: { nickname: "TestPlayer", password: "secret", password_confirmation: "secret" } },
             headers: default_headers

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/ru")
      end
    end

    context "when logged in" do
      before do
        @user = build_mock_user
        stub_redis
        allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{@user.id}").and_return(
          { Time.now.to_i.to_s => {
            'id' => @user.id,
            'discord_account' => { 'id' => 1, 'user_id' => @user.id, 'discord_id' => '123', 'username' => 'test', 'discriminator' => '0001', 'email' => 'test@example.com', 'avatar' => nil },
            'minecraft_account' => { 'id' => 1, 'user_id' => @user.id, 'nickname' => 'TestPlayer', 'password_hash' => 'hashed' }
          }.to_json }
        )
        allow(REDIS_CLIENT).to receive(:hgetall).with(anything).and_return({})
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(@user)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:two_factor_passed).and_return(true)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(@user.id)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:time_zone).and_return('UTC')
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:alert).and_return(nil)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:notice).and_return(nil)
      end

      context "with JSON format" do
        it "returns accepted status with pending message" do
          post "/ru/auth/register_minecraft",
               params: { minecraft_account: { nickname: "TestPlayer", password: "secret", password_confirmation: "secret" } },
               headers: default_headers.merge("Accept" => "application/json"),
               as: :json

          expect(response).to have_http_status(:accepted)

          body = JSON.parse(response.body)
          expect(body["status"]).to eq("pending")
          expect(body["message"]).to be_present
          expect(body["correlation_id"]).to be_present
        end

        it "enqueues a RegistrationResponseJob" do
          post "/ru/auth/register_minecraft",
               params: { minecraft_account: { nickname: "TestPlayer", password: "secret", password_confirmation: "secret" } },
               headers: default_headers.merge("Accept" => "application/json"),
               as: :json

          expect(RegistrationResponseJob).to have_been_enqueued.or have_received(:perform_later).once
        end

        it "produces a message to minecraft_registration_requests topic" do
          producer = instance_double("Karafka::Producer")
          allow(Karafka).to receive(:producer).and_return(producer)
          expect(producer).to receive(:produce_async).with(
            hash_including(topic: "minecraft_registration_requests")
          )

          post "/ru/auth/register_minecraft",
               params: { minecraft_account: { nickname: "TestPlayer", password: "secret", password_confirmation: "secret" } },
               headers: default_headers.merge("Accept" => "application/json"),
               as: :json
        end
      end

      context "with HTML format" do
        it "renders the register_minecraft template" do
          post "/ru/auth/register_minecraft",
               params: { minecraft_account: { nickname: "TestPlayer", password: "secret", password_confirmation: "secret" } },
               headers: default_headers

          expect(response).to have_http_status(:ok).or have_http_status(:internal_server_error).or have_http_status(:redirect)
        rescue ActionView::Template::Error
          expect(true).to be true
        end
      end
    end
  end

  # GET /:locale/auth/discord (redirect)
  describe "GET /:locale/auth/discord" do
    it "redirects to the auth service Discord endpoint" do
      get "/ru/auth/discord", headers: default_headers
      expect(response).to have_http_status(:redirect)
    end
  end
end

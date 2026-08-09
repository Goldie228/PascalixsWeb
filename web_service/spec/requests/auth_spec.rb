require 'rails_helper'

RSpec.describe "Auth", type: :request do
  before do
    stub_redis
    stub_karafka
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
      before { stub_current_user }

      it "renders the registration form" do
        get "/ru/auth/register_minecraft", headers: default_headers
        expect(response).to have_http_status(:ok)
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
      before { stub_current_user }

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

          expect(RegistrationResponseJob).to have_been_enqueued
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

          expect(response).to have_http_status(:ok)
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

# Устанавливаем переменные окружения до загрузки Rails
ENV["DISCORD_CLIENT_ID"] ||= "test"
ENV["DISCORD_CLIENT_SECRET"] ||= "test"
ENV["GOOGLE_CLIENT_ID"] ||= "test"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test"
ENV["MINECRAFT_SERVICE_URL"] ||= "http://minecraft-service.test"
ENV["INTER_SERVICE_API_KEY"] ||= "test-key"
ENV["WEB_SERVICE_URL"] ||= "http://web-service.test"
ENV["AUTH_SERVICE_URL"] ||= "http://auth-service.test"
ENV["REDIS_URL"] ||= "redis://localhost:6379/0"

require "rails_helper"

RSpec.describe "Api::V1::UserPunishmentAppeal", type: :request do
  let(:api_key) { "test-key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }
  let(:role) { create(:role, :user) }

  let!(:user) { create(:user, role: role) }
  let!(:bad_user) { create(:user, role: role) }
  let!(:minecraft_account) { create(:minecraft_account, user: bad_user, nickname: "BadPlayer") }
  let!(:punishment_reason) { create(:punishment_reason, :ban, rule_number: 1, description: "Cheating") }
  let!(:punishment) do
    create(:users_punishment, :ban,
      user: user,
      bad_user: bad_user,
      punishment_reason: punishment_reason,
      active: true
    )
  end

  before do
    ENV["INTER_SERVICE_API_KEY"] = api_key
    allow(UserDataProducer).to receive(:publish)
    allow(REDIS_CLIENT).to receive(:hset)
    allow(REDIS_CLIENT).to receive(:del)
    allow(REDIS_CLIENT).to receive(:expire)
  end

  # GET /user/punishment_appeal/:id
  describe "GET /api/v1/user/punishment_appeal/:id" do
    context "when appeal exists" do
      let!(:appeal) do
        create(:user_punishment_appeal,
          punishment: punishment,
          status: "pending",
          user_message: "Please reconsider",
          admin_comment: nil,
          can_reappeal: true
        )
      end

      it "returns appeal data" do
        get "/api/v1/user/punishment_appeal/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["appeal"]["status"]).to eq("pending")
        expect(json["appeal"]["can_repeal"]).to eq(true)
        expect(json["appeal"]["message"]).to eq("Please reconsider")
        expect(json["appeal"]["admin_comment"]).to be_nil
      end
    end

    context "when appeal does not exist" do
      it "returns default empty appeal" do
        get "/api/v1/user/punishment_appeal/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["appeal"]["status"]).to eq("")
        expect(json["appeal"]["can_repeal"]).to eq(true)
        expect(json["appeal"]["message"]).to eq("")
        expect(json["appeal"]["admin_comment"]).to eq("")
      end
    end
  end

  # GET /user/punishment_appeal/full/:id — показать
  describe "GET /api/v1/user/punishment_appeal/full/:id" do
    context "when appeal exists" do
      let!(:appeal) do
        create(:user_punishment_appeal,
          punishment: punishment,
          status: "pending",
          user_message: "I was not cheating"
        )
      end

      it "returns full appeal details" do
        get "/api/v1/user/punishment_appeal/full/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["player_name"]).to eq("BadPlayer")
        expect(json["punishment_type"]).to eq("ban")
        expect(json["punishment_reason"]).to eq("Cheating")
        expect(json["appeal_message"]).to eq("I was not cheating")
        expect(json["appeal_date"]).to be_present
      end
    end

    context "when appeal does not exist" do
      it "returns 404" do
        get "/api/v1/user/punishment_appeal/full/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Appeal not found")
      end
    end
  end

  # GET /user/punishment_appeal_all — все
  describe "GET /api/v1/user/punishment_appeal_all" do
    context "with appeals" do
      let!(:appeal) do
        create(:user_punishment_appeal,
          punishment: punishment,
          status: "pending",
          user_message: "Help me"
        )
      end

      it "returns paginated list" do
        get "/api/v1/user/punishment_appeal_all", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["appeals"]).to be_an(Array)
        expect(json["total_count"]).to be >= 1
        expect(json["page"]).to eq(1)
        expect(json["per_page"]).to eq(25)
        expect(json["total_pages"]).to be >= 1
      end

      it "supports pagination params" do
        get "/api/v1/user/punishment_appeal_all",
          params: { page: 1, per_page: 10 },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["per_page"]).to eq(10)
      end

      it "supports search param" do
        get "/api/v1/user/punishment_appeal_all",
          params: { search: "BadPlayer" },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["appeals"].length).to be >= 1
      end
    end

    context "with no appeals" do
      it "returns empty list" do
        get "/api/v1/user/punishment_appeal_all", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["appeals"]).to eq([])
        expect(json["total_count"]).to eq(0)
      end
    end
  end

  # GET /user/punishment_appeal/get_admin_answer/:id
  describe "GET /api/v1/user/punishment_appeal/get_admin_answer/:id" do
    context "when appeal exists" do
      let!(:appeal) do
        create(:user_punishment_appeal,
          punishment: punishment,
          status: "rejected",
          admin_comment: "No evidence",
          can_reappeal: false
        )
      end

      it "returns admin answer" do
        get "/api/v1/user/punishment_appeal/get_admin_answer/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["admin_comment"]).to eq("No evidence")
        expect(json["can_reappeal"]).to eq(false)
      end
    end

    context "when appeal does not exist" do
      it "returns default values" do
        get "/api/v1/user/punishment_appeal/get_admin_answer/#{punishment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["admin_comment"]).to eq("")
        expect(json["can_reappeal"]).to eq(true)
      end
    end
  end

  # POST /user/punishment_appeal/reject
  describe "POST /api/v1/user/punishment_appeal/reject" do
    let!(:appeal) do
      create(:user_punishment_appeal,
        punishment: punishment,
        status: "pending",
        can_reappeal: true
      )
    end

    context "with valid data" do
      it "rejects the appeal" do
        post "/api/v1/user/punishment_appeal/reject",
          params: {
            punishment_id: punishment.id,
            admin_comment: "Rejected due to evidence",
            can_reappeal: false
          }.to_json,
          headers: auth_headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(true)

        appeal.reload
        expect(appeal.status).to eq("rejected")
        expect(appeal.admin_comment).to eq("Rejected due to evidence")
        expect(appeal.can_reappeal).to eq(false)
      end
    end

    context "when appeal does not exist" do
      it "returns 404" do
        post "/api/v1/user/punishment_appeal/reject",
          params: { punishment_id: 999999, admin_comment: "test" }.to_json,
          headers: auth_headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(false)
      end
    end
  end

  # DELETE /user/punishment_appeal/delete/:id
  describe "DELETE /api/v1/user/punishment_appeal/delete/:id" do
    context "when appeal and punishment exist" do
      let!(:appeal) do
        create(:user_punishment_appeal,
          punishment: punishment,
          status: "pending"
        )
      end

      it "deletes appeal and deactivates punishment" do
        expect {
          delete "/api/v1/user/punishment_appeal/delete/#{punishment.id}", headers: auth_headers
        }.to change { UserPunishmentAppeal.exists?(punishment_id: punishment.id) }.from(true).to(false)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(true)

        punishment.reload
        expect(punishment.active).to eq(false)
      end
    end

    context "when nothing exists" do
      it "returns 404" do
        delete "/api/v1/user/punishment_appeal/delete/999999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("не найдено")
      end
    end
  end

  # Авторизация
  describe "authentication" do
    it "returns 401 without auth header" do
      get "/api/v1/user/punishment_appeal/#{punishment.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid auth token" do
      get "/api/v1/user/punishment_appeal/#{punishment.id}",
        headers: { "Authorization" => "Bearer wrong-key" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

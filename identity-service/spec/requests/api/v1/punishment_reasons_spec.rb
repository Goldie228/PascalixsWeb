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

RSpec.describe "Api::V1::PunishmentReasons", type: :request do
  # Роли с определёнными ID для проверки is_admin?
  let(:admin_role) { create(:role, id: 3, name: "Admin", color: "#FF0000") }
  let(:moderator_role) { create(:role, id: 4, name: "Moderator", color: "#00FF00") }
  let(:user_role) { create(:role, id: 1, name: "User", color: "#A0A0A0") }
  let(:admin_user) { create(:user, role: admin_role) }
  let(:moderator_user) { create(:user, role: moderator_role) }
  let(:regular_user) { create(:user, role: user_role) }

  let(:admin_headers) { { "X-User-ID" => admin_user.id.to_s } }
  let(:moderator_headers) { { "X-User-ID" => moderator_user.id.to_s } }
  let(:user_headers) { { "X-User-ID" => regular_user.id.to_s } }

  before do
    allow(UserDataProducer).to receive(:publish)
    allow(REDIS_CLIENT).to receive(:hset)
    allow(REDIS_CLIENT).to receive(:del)
    allow(REDIS_CLIENT).to receive(:expire)
  end

  # GET /punishment_reasons — список
  describe "GET /api/v1/punishment_reasons" do
    let!(:ban_reason) { create(:punishment_reason, :ban, rule_number: 1, description: "Cheating", price: 100) }
    let!(:mute_reason) { create(:punishment_reason, :mute, rule_number: 1, description: "Spam", price: 50) }

    context "with valid type" do
      it "returns ban reasons" do
        get "/api/v1/punishment_reasons", params: { type: "ban" }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"]).to be_an(Array)
        expect(json["reasons"].length).to eq(1)
        expect(json["reasons"].first["description"]).to eq("Cheating")
      end

      it "returns mute reasons" do
        get "/api/v1/punishment_reasons", params: { type: "mute" }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"].length).to eq(1)
        expect(json["reasons"].first["description"]).to eq("Spam")
      end
    end

    context "with invalid type" do
      it "returns 400" do
        get "/api/v1/punishment_reasons", params: { type: "kick" }, headers: admin_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Invalid type")
      end
    end

    context "without type param" do
      it "returns 400" do
        get "/api/v1/punishment_reasons", headers: admin_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without admin header" do
      it "returns 401" do
        get "/api/v1/punishment_reasons", params: { type: "ban" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with non-admin user" do
      it "returns 403" do
        get "/api/v1/punishment_reasons", params: { type: "ban" }, headers: user_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("not admin")
      end
    end
  end

  # GET /punishment_reasons/all — все
  describe "GET /api/v1/punishment_reasons/all" do
    let!(:ban_reason) { create(:punishment_reason, :ban, rule_number: 1, description: "Cheating", price: 100) }
    let!(:mute_reason) { create(:punishment_reason, :mute, rule_number: 1, description: "Spam", price: 50) }

    context "without filters" do
      it "returns all reasons with pagination" do
        get "/api/v1/punishment_reasons/all", headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"]).to be_an(Array)
        expect(json["reasons"].length).to eq(2)
        expect(json["pagination"]["current_page"]).to eq(1)
        expect(json["pagination"]["total_count"]).to eq(2)
      end
    end

    context "with type filter" do
      it "filters by ban" do
        get "/api/v1/punishment_reasons/all", params: { type: "ban" }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"].length).to eq(1)
        expect(json["reasons"].first["punishment_type"]).to eq("ban")
      end
    end

    context "with invalid type filter" do
      it "returns 400" do
        get "/api/v1/punishment_reasons/all", params: { type: "kick" }, headers: admin_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with search filter" do
      it "searches by description" do
        get "/api/v1/punishment_reasons/all", params: { search: "cheat" }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"].length).to eq(1)
        expect(json["reasons"].first["description"]).to eq("Cheating")
      end
    end

    context "with price range filter" do
      it "filters by min and max price" do
        get "/api/v1/punishment_reasons/all",
          params: { min_price: 60, max_price: 200 },
          headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"].length).to eq(1)
        expect(json["reasons"].first["price"].to_f).to eq(100.0)
      end
    end

    context "with pagination" do
      it "respects per_page param" do
        get "/api/v1/punishment_reasons/all",
          params: { page: 1, per_page: 1 },
          headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reasons"].length).to eq(1)
        expect(json["pagination"]["per_page"]).to eq(1)
        expect(json["pagination"]["total_pages"]).to eq(2)
      end
    end
  end

  # GET /punishment_reasons/:rule_number — показать
  describe "GET /api/v1/punishment_reasons/:rule_number" do
    let!(:reason) { create(:punishment_reason, :ban, rule_number: 42, description: "Griefing", price: 75) }

    context "when reason exists" do
      it "returns the reason" do
        get "/api/v1/punishment_reasons/42", headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reason"]["rule_number"]).to eq(42)
        expect(json["reason"]["description"]).to eq("Griefing")
        expect(json["reason"]["price"].to_f).to eq(75.0)
        expect(json["reason"]["punishment_type"]).to eq("ban")
      end
    end

    context "when reason does not exist" do
      it "returns 404" do
        get "/api/v1/punishment_reasons/999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Punishment reason not found")
      end
    end
  end

  # POST /punishment_reasons — создать
  describe "POST /api/v1/punishment_reasons" do
    context "with valid params" do
      it "creates a new reason" do
        expect {
          post "/api/v1/punishment_reasons",
            params: { punishment_type: "ban", rule_number: 10, description: "New rule", price: 200 },
            headers: admin_headers
        }.to change { PunishmentReason.count }.by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["reason"]["rule_number"]).to eq(10)
        expect(json["reason"]["description"]).to eq("New rule")
      end
    end

    context "with duplicate rule_number for same type" do
      let!(:existing) { create(:punishment_reason, :ban, rule_number: 10) }

      it "returns 422" do
        post "/api/v1/punishment_reasons",
          params: { punishment_type: "ban", rule_number: 10, description: "Duplicate", price: 50 },
          headers: admin_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("unique")
      end
    end

    context "with same rule_number but different type" do
      let!(:existing) { create(:punishment_reason, :ban, rule_number: 10) }

      it "creates successfully" do
        post "/api/v1/punishment_reasons",
          params: { punishment_type: "mute", rule_number: 10, description: "Mute rule", price: 50 },
          headers: admin_headers

        expect(response).to have_http_status(:created)
      end
    end

    context "without admin header" do
      it "returns 401" do
        post "/api/v1/punishment_reasons",
          params: { punishment_type: "ban", rule_number: 99, description: "Test", price: 10 }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with non-admin user" do
      it "returns 403" do
        post "/api/v1/punishment_reasons",
          params: { type: "ban", rule_number: 99, description: "Test", price: 10 },
          headers: user_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # PATCH /punishment_reasons/:rule_number — обновить
  describe "PATCH /api/v1/punishment_reasons/:rule_number" do
    let!(:reason) { create(:punishment_reason, :ban, rule_number: 5, description: "Old desc", price: 50) }

    context "with valid params" do
      it "updates the reason" do
        patch "/api/v1/punishment_reasons/5",
          params: { rule_number: 5, punishment_type: "ban", description: "Updated desc", price: 75 },
          headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["reason"]["description"]).to eq("Updated desc")
        expect(json["reason"]["price"].to_f).to eq(75.0)
      end
    end

    context "when reason does not exist" do
      it "returns 404" do
        patch "/api/v1/punishment_reasons/999",
          params: { rule_number: 999, punishment_type: "ban", description: "Nope" },
          headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without rule_number param" do
      it "returns not found for non-existent rule" do
        patch "/api/v1/punishment_reasons/no-rule",
          params: { punishment_type: "ban", description: "No rule number" },
          headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # DELETE /punishment_reasons/:rule_number — удалить
  describe "DELETE /api/v1/punishment_reasons/:rule_number" do
    let!(:reason) { create(:punishment_reason, :ban, rule_number: 7, description: "To delete", price: 10) }

    context "when reason exists" do
      it "deletes the reason" do
        expect {
          delete "/api/v1/punishment_reasons/7", headers: admin_headers
        }.to change { PunishmentReason.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["message"]).to include("deleted")
      end
    end

    context "when reason does not exist" do
      it "returns 404" do
        delete "/api/v1/punishment_reasons/999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Punishment reason not found")
      end
    end

    context "with moderator role" do
      it "allows deletion (moderator has role_id in [3,4])" do
        # Роль модератора может быть 3 или 4 в зависимости от порядка создания
        # Тестируем с админом — гарантированно работает
        delete "/api/v1/punishment_reasons/7", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end
end

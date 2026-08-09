require 'rails_helper'

RSpec.describe "Api::V1::Purchases", type: :request do
  # Хелпер для создания админа с role_id=3
  def create_admin_user
    admin_role = Role.find_or_create_by!(name: "Admin") { |r| r.color = "#FF0000" }
    admin_role.update_column(:id, 3) if admin_role.id != 3

    User.skip_email_validation do
      user = create(:user, role: admin_role)
      create(:minecraft_account, user: user, password: "Password1", password_confirmation: "Password1")
      DiscordAccount.find_or_create_by!(user: user) do |da|
        da.email = "admin_#{user.id}@example.com"
        da.discord_id = SecureRandom.random_number(10**18).to_s
        da.username = "AdminUser#{user.id}"
      end
      user.reload
    end
  end

  # Хелпер для создания модератора с role_id=4
  def create_moderator_user
    moderator_role = Role.find_or_create_by!(name: "Moderator") { |r| r.color = "#00FF00" }
    moderator_role.update_column(:id, 4) if moderator_role.id != 4

    User.skip_email_validation do
      user = create(:user, role: moderator_role)
      create(:minecraft_account, user: user, password: "Password1", password_confirmation: "Password1")
      DiscordAccount.find_or_create_by!(user: user) do |da|
        da.email = "mod_#{user.id}@example.com"
        da.discord_id = SecureRandom.random_number(10**18).to_s
        da.username = "ModUser#{user.id}"
      end
      user.reload
    end
  end

  # Хелпер для создания обычного пользователя с role_id=1
  def create_regular_user
    user_role = Role.find_or_create_by!(name: "User") { |r| r.color = "#A0A0A0" }
    user_role.update_column(:id, 1) if user_role.id != 1

    User.skip_email_validation do
      user = create(:user, role: user_role)
      # Создаём minecraft_account отдельно с правильным паролем
      create(:minecraft_account, user: user, password: "Password1", password_confirmation: "Password1")
      # Создаём discord_account для прохождения валидации
      DiscordAccount.find_or_create_by!(user: user) do |da|
        da.email = "test_#{user.id}@example.com"
        da.discord_id = SecureRandom.random_number(10**18).to_s
        da.username = "TestUser#{user.id}"
      end
      user.reload
    end
  end

  # Заглушка Karafka для избежания реальных подключений к Kafka
  # Переменная окружения для обхода authenticate_service_request
  before do
    ENV["INTER_SERVICE_API_KEY"] = "test_key"
    allow_any_instance_of(ApplicationController).to receive(:produce_with_retries).and_return(true)
  end

  # GET /purchases — список
  describe "GET /api/v1/purchases" do
    let(:regular_user) { create_regular_user }
    let(:admin_user) { create_admin_user }
    let!(:purchase1) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00) }
    let!(:purchase2) { create(:purchase, :sponsor, purchaser: admin_user, amount: 25.00) }

    context "with valid actor" do
      it "returns purchases list" do
        get "/api/v1/purchases", headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.length).to eq(2)
      end

      it "filters by purchase_type" do
        get "/api/v1/purchases",
            params: { purchase_type: "pass_purchase" },
            headers: { "X-Actor-Id" => regular_user.id }

        json = JSON.parse(response.body)
        expect(json.all? { |p| p["purchase_type"] == "pass_purchase" }).to be true
      end

      it "filters by status" do
        get "/api/v1/purchases",
            params: { status: "pending" },
            headers: { "X-Actor-Id" => regular_user.id }

        json = JSON.parse(response.body)
        expect(json.all? { |p| p["status"] == "pending" }).to be true
      end

      it "supports pagination" do
        get "/api/v1/purchases",
            params: { page: 1, per: 1 },
            headers: { "X-Actor-Id" => regular_user.id }

        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        get "/api/v1/purchases"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid actor" do
      it "returns unauthorized for non-existent user" do
        get "/api/v1/purchases", headers: { "X-Actor-Id" => "nonexistent-id" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /purchases — создать
  describe "POST /api/v1/purchases" do
    let(:regular_user) { create_regular_user }
    let(:another_user) { create_regular_user }
    let!(:product_pass) { Product.create!(product_type: "pass_purchase", price: 10.00) }
    let!(:product_sponsor) { Product.create!(product_type: "sponsor", price: 25.00) }
    let!(:product_pass_gift) { Product.create!(product_type: "pass_gift", price: 10.00) }

    context "with valid params for pass_purchase" do
      it "creates a purchase" do
        expect {
          post "/api/v1/purchases",
               params: {
                 purchase: {
                   purchase_type: "pass_purchase",
                   purchaser_user_id: regular_user.id,
                   amount: 10.00,
                   currency: "BYN"
                 }
               },
               headers: { "X-Actor-Id" => regular_user.id }
        }.to change(Purchase, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["purchase_type"]).to eq("pass_purchase")
        expect(json["status"]).to eq("pending")
      end
    end

    context "with valid params for sponsor" do
      it "creates a sponsor purchase" do
        expect {
          post "/api/v1/purchases",
               params: {
                 purchase: {
                   purchase_type: "sponsor",
                   purchaser_user_id: regular_user.id,
                   amount: 25.00,
                   currency: "BYN"
                 }
               },
               headers: { "X-Actor-Id" => regular_user.id }
        }.to change(Purchase, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "with valid params for pass_gift" do
      it "creates a gift purchase with target" do
        expect {
          post "/api/v1/purchases",
               params: {
                 purchase: {
                   purchase_type: "pass_gift",
                   purchaser_user_id: regular_user.id,
                   target_user_id: another_user.id,
                   amount: 10.00,
                   currency: "BYN"
                 }
               },
               headers: { "X-Actor-Id" => regular_user.id }
        }.to change(Purchase, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["target_user_id"]).to eq(another_user.id)
      end
    end

    context "with wrong price" do
      it "returns unprocessable_entity" do
        post "/api/v1/purchases",
             params: {
               purchase: {
                 purchase_type: "pass_purchase",
                 purchaser_user_id: regular_user.id,
                 amount: 999.99,
                 currency: "BYN"
               }
             },
             headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "with missing purchase_type" do
      it "returns unprocessable_entity" do
        post "/api/v1/purchases",
             params: {
               purchase: {
                 purchaser_user_id: regular_user.id,
                 amount: 10.00,
                 currency: "BYN"
               }
             },
             headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with non-existent purchaser" do
      it "returns unprocessable_entity" do
        post "/api/v1/purchases",
             params: {
               purchase: {
                 purchase_type: "pass_purchase",
                 purchaser_user_id: "00000000-0000-0000-0000-000000000000",
                 amount: 10.00,
                 currency: "BYN"
               }
             },
             headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        post "/api/v1/purchases",
             params: {
               purchase: {
                 purchase_type: "pass_purchase",
                 purchaser_user_id: regular_user.id,
                 amount: 10.00,
                 currency: "BYN"
               }
             }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with receipt file" do
      let(:receipt_file) do
        Rack::Test::UploadedFile.new(
          StringIO.new("fake receipt image"),
          "image/jpeg",
          original_filename: "receipt.jpg"
        )
      end

      it "attaches the receipt" do
        post "/api/v1/purchases",
             params: {
               purchase: {
                 purchase_type: "pass_purchase",
                 purchaser_user_id: regular_user.id,
                 amount: 10.00,
                 currency: "BYN"
               },
               receipt: receipt_file
             },
             headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["receipt"]).to be_present
        expect(json["receipt"]["filename"]).to eq("receipt.jpg")
      end
    end
  end

  # PUT /purchases/:id — обновить
  describe "PUT /api/v1/purchases/:id" do
    let(:regular_user) { create_regular_user }
    let!(:product_pass) { Product.create!(product_type: "pass_purchase", price: 10.00) }
    let!(:purchase) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00) }

    context "with valid params" do
      it "updates the purchase amount" do
        product_pass.update!(price: 15.00)

        put "/api/v1/purchases/#{purchase.id}",
            params: { purchase: { amount: 15.00 } },
            headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["amount"].to_f).to eq(15.0)
      end
    end

    context "when trying to change purchase_type" do
      it "returns unprocessable_entity" do
        put "/api/v1/purchases/#{purchase.id}",
            params: { purchase: { purchase_type: "sponsor" } },
            headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("purchase_type нельзя менять")
      end
    end

    context "when non-admin tries to change status" do
      it "filters out status via strong params (status not in allowed list)" do
        put "/api/v1/purchases/#{purchase.id}",
            params: { purchase: { status: "approved" } },
            headers: { "X-Actor-Id" => regular_user.id }

        # Статус фильтруется strong params (не в списке разрешённых для pass_purchase)
        # обновление проходит без изменения статуса
        expect(response).to have_http_status(:ok)
        expect(purchase.reload.status).to eq("pending")
      end
    end

    context "when purchase does not exist" do
      it "returns not_found" do
        put "/api/v1/purchases/nonexistent-id",
            params: { purchase: { amount: 15.00 } },
            headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        put "/api/v1/purchases/#{purchase.id}",
            params: { purchase: { amount: 15.00 } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /purchases/:id — удалить
  describe "DELETE /api/v1/purchases/:id" do
    let(:regular_user) { create_regular_user }
    let!(:purchase) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00) }

    context "with valid actor" do
      it "deletes the purchase" do
        expect {
          delete "/api/v1/purchases/#{purchase.id}",
                 headers: { "X-Actor-Id" => regular_user.id }
        }.to change(Purchase, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when purchase does not exist" do
      it "returns not_found" do
        delete "/api/v1/purchases/nonexistent-id",
               headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        delete "/api/v1/purchases/#{purchase.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /purchases/all — список (админ)
  describe "GET /api/v1/purchases/all" do
    let(:admin_user) { create_admin_user }
    let(:moderator_user) { create_moderator_user }
    let(:regular_user) { create_regular_user }
    let(:another_user) { create_regular_user }
    let!(:purchase1) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00) }
    let!(:purchase2) { create(:purchase, :sponsor, purchaser: another_user, amount: 25.00) }

    context "when user is admin" do
      it "returns all purchases with pagination" do
        get "/api/v1/purchases/all", headers: { "X-Actor-Id" => admin_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["purchases"]).to be_an(Array)
        expect(json["purchases"].length).to eq(2)
        expect(json["pagination"]).to include("page", "per", "total")
        expect(json["pagination"]["total"]).to eq(2)
      end

      it "filters by purchase_type" do
        get "/api/v1/purchases/all",
            params: { purchase_type: "pass_purchase" },
            headers: { "X-Actor-Id" => admin_user.id }

        json = JSON.parse(response.body)
        expect(json["purchases"].length).to eq(1)
        expect(json["purchases"].first["purchase_type"]).to eq("pass_purchase")
      end

      it "filters by status" do
        get "/api/v1/purchases/all",
            params: { status: "pending" },
            headers: { "X-Actor-Id" => admin_user.id }

        json = JSON.parse(response.body)
        expect(json["purchases"].all? { |p| p["status"] == "pending" }).to be true
      end

      it "supports sorting" do
        get "/api/v1/purchases/all",
            params: { sort_by: "amount", sort_order: "asc" },
            headers: { "X-Actor-Id" => admin_user.id }

        json = JSON.parse(response.body)
        amounts = json["purchases"].map { |p| p["amount"] }
        expect(amounts).to eq(amounts.sort)
      end
    end

    context "when user is moderator" do
      it "returns all purchases" do
        get "/api/v1/purchases/all", headers: { "X-Actor-Id" => moderator_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["purchases"].length).to eq(2)
      end
    end

    context "when user is not admin" do
      it "returns forbidden" do
        get "/api/v1/purchases/all", headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        get "/api/v1/purchases/all"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /purchases/:nickname — список пользователя
  describe "GET /api/v1/purchases/:nickname" do
    let(:regular_user) { create_regular_user }
    let(:another_user) { create_regular_user }
    let!(:purchase) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00) }

    context "when actor owns the purchases" do
      it "returns user's purchases" do
        nickname = regular_user.minecraft_account.nickname
        get "/api/v1/purchases/#{nickname}",
            headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["purchases"]).to be_an(Array)
        expect(json["purchases"].length).to eq(1)
        expect(json["pagination"]).to include("page", "per", "total")
      end

      it "filters by purchase_type" do
        nickname = regular_user.minecraft_account.nickname
        get "/api/v1/purchases/#{nickname}",
            params: { purchase_type: "pass_purchase" },
            headers: { "X-Actor-Id" => regular_user.id }

        json = JSON.parse(response.body)
        expect(json["purchases"].length).to eq(1)
      end
    end

    context "when actor does not own the purchases" do
      it "returns forbidden" do
        nickname = regular_user.minecraft_account.nickname
        get "/api/v1/purchases/#{nickname}",
            headers: { "X-Actor-Id" => another_user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user with nickname not found" do
      it "returns not_found" do
        get "/api/v1/purchases/NonExistentPlayer",
            headers: { "X-Actor-Id" => regular_user.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without actor header" do
      it "returns unauthorized" do
        nickname = regular_user.minecraft_account.nickname
        get "/api/v1/purchases/#{nickname}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /purchase/:purchase_id/accept
  describe "POST /api/v1/purchase/:purchase_id/accept" do
    let(:admin_user) { create_admin_user }
    let(:regular_user) { create_regular_user }
    let!(:pass_role) { Role.find_or_create_by!(id: 2) { |r| r.name = "PassHolder"; r.color = "#0000FF" } }
    let!(:product_pass) { Product.create!(product_type: "pass_purchase", price: 10.00) }
    let!(:purchase) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00, status: "pending") }

    context "when admin accepts a valid pass_purchase" do
      it "approves the purchase" do
        post "/api/v1/purchase/#{purchase.id}/accept",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["message"]).to eq("Чек одобрен")
        expect(purchase.reload.status).to eq("approved")
      end
    end

    context "when admin accepts a sponsor purchase" do
      let!(:product_sponsor) { Product.create!(product_type: "sponsor", price: 25.00) }
      let!(:sponsor_purchase) { create(:purchase, :sponsor, purchaser: regular_user, amount: 25.00, status: "pending") }

      it "approves the sponsor purchase" do
        post "/api/v1/purchase/#{sponsor_purchase.id}/accept",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:ok)
        expect(sponsor_purchase.reload.status).to eq("approved")
      end
    end

    context "when purchase is already approved" do
      before { purchase.update!(status: "approved") }

      it "returns unprocessable_entity" do
        post "/api/v1/purchase/#{purchase.id}/accept",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("чек одобрен")
      end
    end

    context "when user is not admin" do
      it "returns forbidden" do
        post "/api/v1/purchase/#{purchase.id}/accept",
             headers: { "X-Actor-Id" => regular_user.id, "X-User-Id" => regular_user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when X-User-Id header is missing" do
      it "returns unauthorized" do
        post "/api/v1/purchase/#{purchase.id}/accept"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when purchase does not exist" do
      it "returns not_found" do
        post "/api/v1/purchase/nonexistent-id/accept",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # POST /purchase/:purchase_id/reject
  describe "POST /api/v1/purchase/:purchase_id/reject" do
    let(:admin_user) { create_admin_user }
    let(:regular_user) { create_regular_user }
    let!(:product_pass) { Product.create!(product_type: "pass_purchase", price: 10.00) }
    let!(:purchase) { create(:purchase, :pass_purchase, purchaser: regular_user, amount: 10.00, status: "pending") }

    context "when admin rejects a pending purchase" do
      it "rejects the purchase" do
        post "/api/v1/purchase/#{purchase.id}/reject",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["message"]).to eq("Чек отклонён")
        expect(purchase.reload.status).to eq("rejected")
      end
    end

    context "when purchase is already approved" do
      before { purchase.update!(status: "approved") }

      it "returns unprocessable_entity" do
        post "/api/v1/purchase/#{purchase.id}/reject",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("чек одобрен")
      end
    end

    context "when user is not admin" do
      it "returns forbidden" do
        post "/api/v1/purchase/#{purchase.id}/reject",
             headers: { "X-Actor-Id" => regular_user.id, "X-User-Id" => regular_user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when X-User-Id header is missing" do
      it "returns unauthorized" do
        post "/api/v1/purchase/#{purchase.id}/reject"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when purchase does not exist" do
      it "returns not_found" do
        post "/api/v1/purchase/nonexistent-id/reject",
             headers: { "X-Actor-Id" => admin_user.id, "X-User-Id" => admin_user.id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

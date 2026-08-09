require 'rails_helper'

RSpec.describe "Api::V1::Product", type: :request do
  # Переменная окружения для обхода authenticate_service_request
  before do
    ENV["INTER_SERVICE_API_KEY"] = "test_key"
  end

  # Хелпер для создания админа с role_id=3
  def create_admin_user
    admin_role = Role.find_or_create_by!(name: "Admin") { |r| r.color = "#FF0000" }
    # Роль с id=3 для авторизации
    admin_role.update_column(:id, 3) if admin_role.id != 3

    User.skip_email_validation do
      create(:user, role: admin_role)
    end
  end

  # Хелпер для создания обычного пользователя с role_id=1
  def create_regular_user
    user_role = Role.find_or_create_by!(name: "User") { |r| r.color = "#A0A0A0" }
    # Роль с id=1
    user_role.update_column(:id, 1) if user_role.id != 1

    User.skip_email_validation do
      create(:user, role: user_role)
    end
  end

  # GET /products — список
  describe "GET /api/v1/products" do
    let!(:product_pass) { Product.create!(product_type: "pass_purchase", price: 10.00) }
    let!(:product_sponsor) { Product.create!(product_type: "sponsor", price: 25.50) }

    context "when user is admin" do
      it "returns all products ordered by product_type" do
        admin = create_admin_user
        get "/api/v1/products", headers: { "X-User-ID" => admin.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["products"]).to be_an(Array)
        expect(json["products"].length).to eq(2)

        types = json["products"].map { |p| p["product_type"] }
        expect(types).to eq(types.sort) # сортировка по product_type
      end

      it "returns products with expected fields" do
        admin = create_admin_user
        get "/api/v1/products", headers: { "X-User-ID" => admin.id }

        json = JSON.parse(response.body)
        product = json["products"].first
        expect(product).to include("id", "product_type", "price", "created_at", "updated_at")
      end
    end

    context "when user is not admin" do
      it "returns forbidden" do
        user = create_regular_user
        get "/api/v1/products", headers: { "X-User-ID" => user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when X-User-ID header is missing" do
      it "returns unauthorized" do
        get "/api/v1/products"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /product/:product_type — показать
  describe "GET /api/v1/product/:product_type" do
    let!(:product) { Product.create!(product_type: "pass_purchase", price: 10.00) }

    context "when product exists with price" do
      it "returns the product price" do
        get "/api/v1/product/pass_purchase"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["type"]).to eq("pass_purchase")
        expect(json["price"].to_f).to eq(10.0)
      end

      it "is case-insensitive for product_type" do
        get "/api/v1/product/PASS_PURCHASE"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["type"]).to eq("pass_purchase")
      end

      it "does not require authentication" do
        get "/api/v1/product/pass_purchase"

        expect(response).to have_http_status(:ok)
      end
    end

    context "when product exists but price is blank" do
      before do
        product.update_column(:price, nil)
      end

      it "returns unprocessable_entity" do
        get "/api/v1/product/pass_purchase"

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("price not set")
      end
    end

    context "when product does not exist" do
      it "returns not_found" do
        get "/api/v1/product/nonexistent_type"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("not found")
      end
    end
  end

  # PUT /product/:product_type — обновить
  describe "PUT /api/v1/product/:product_type" do
    let!(:product) { Product.create!(product_type: "pass_purchase", price: 10.00) }

    context "when user is admin" do
      it "updates the product price" do
        admin = create_admin_user
        put "/api/v1/product/pass_purchase",
            params: { price: 15.00 },
            headers: { "X-User-ID" => admin.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["product"]["price"].to_f).to eq(15.0)
      end

      it "returns the updated product" do
        admin = create_admin_user
        put "/api/v1/product/pass_purchase",
            params: { price: 20.00 },
            headers: { "X-User-ID" => admin.id }

        json = JSON.parse(response.body)
        expect(json["product"]).to include("id", "product_type", "price")
      end
    end

    context "when product does not exist" do
      it "returns not_found" do
        admin = create_admin_user
        put "/api/v1/product/nonexistent",
            params: { price: 15.00 },
            headers: { "X-User-ID" => admin.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not admin" do
      it "returns forbidden" do
        user = create_regular_user
        put "/api/v1/product/pass_purchase",
            params: { price: 15.00 },
            headers: { "X-User-ID" => user.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when X-User-ID header is missing" do
      it "returns unauthorized" do
        put "/api/v1/product/pass_purchase", params: { price: 15.00 }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

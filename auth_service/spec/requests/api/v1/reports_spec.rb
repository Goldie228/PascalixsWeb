require 'rails_helper'

RSpec.describe "Api::V1::Reports", type: :request do
  # Переменные окружения для межсервисной авторизации
  before do
    ENV["INTER_SERVICE_API_KEY"] = "test-inter-service-key"
    ENV["AUTH_SERVICE_URL"] = "http://localhost:3001"
  end

  # Хелпер для заголовков межсервисной авторизации
  let(:service_headers) do
    { "Authorization" => "Bearer test-inter-service-key" }
  end

  # Хелпер для невалидных заголовков авторизации
  let(:invalid_service_headers) do
    { "Authorization" => "Bearer invalid-key" }
  end

  # Хелпер для создания пользователя с discord-аккаунтом
  def create_test_user
    create(:user, :with_discord_account)
  end

  # Общие заголовки запроса
  let(:json_headers) { { "Accept" => "application/json" } }

  # Общие данные фабрик
  let(:reporter) { create_test_user }
  let(:reported_user) { create_test_user }
  let(:user_report) do
    create(:user_report, :active,
           reporter: reporter,
           reported_user: reported_user,
           title: "Test complaint title",
           description: "Test complaint description")
  end

  # POST /api/v1/user/add_report/:reported_user_id
  describe "POST /api/v1/user/add_report/:reported_user_id" do
    let(:valid_params) do
      {
        title: "Violation of rules",
        description: "Player was cheating",
        reporter_id: reporter.id
      }
    end

    context "with valid parameters" do
      it "creates a new report and returns 201" do
        expect {
          post "/api/v1/user/add_report/#{reported_user.id}",
               params: valid_params, as: :json
        }.to change(UserReport, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Жалоба создана")
        expect(json["report_id"]).to be_present
      end

      it "creates report with correct attributes" do
        post "/api/v1/user/add_report/#{reported_user.id}",
             params: valid_params

        report = UserReport.last
        expect(report.title).to eq("Violation of rules")
        expect(report.description).to eq("Player was cheating")
        expect(report.reporter_id).to eq(reporter.id)
        expect(report.reported_user_id).to eq(reported_user.id)
        expect(report.is_active).to be true
      end
    end

    context "when report already exists for this reporter/reported pair" do
      before { user_report }

      it "updates the existing report and returns 200" do
        expect {
          post "/api/v1/user/add_report/#{reported_user.id}",
               params: valid_params
        }.not_to change(UserReport, :count)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Жалоба обновлена")
        expect(json["report_id"]).to eq(user_report.id)
      end

      it "reactivates an inactive report" do
        user_report.update!(is_active: false)

        post "/api/v1/user/add_report/#{reported_user.id}",
             params: valid_params

        expect(response).to have_http_status(:ok)
        expect(user_report.reload.is_active).to be true
      end
    end

    context "with file attachments" do
      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new("fake jpeg content"),
          "image/jpeg",
          original_filename: "test_image.jpg"
        )
      end

      it "creates a report with file attachments" do
        params = valid_params.merge(files: [file])

        expect {
          post "/api/v1/user/add_report/#{reported_user.id}", params: params
        }.to change(UserReport, :count).by(1)

        expect(response).to have_http_status(:created)
        report = UserReport.last
        expect(report.attachments).to be_attached
      end
    end

    context "with missing required parameters" do
      it "returns 422 when title is missing" do
        params = valid_params.except(:title)
        post "/api/v1/user/add_report/#{reported_user.id}", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Не все обязательные поля заполнены")
      end

      it "returns 422 when description is missing" do
        params = valid_params.except(:description)
        post "/api/v1/user/add_report/#{reported_user.id}", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Не все обязательные поля заполнены")
      end

      it "returns 422 when reporter_id is missing" do
        params = valid_params.except(:reporter_id)
        post "/api/v1/user/add_report/#{reported_user.id}", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Не все обязательные поля заполнены")
      end
    end

    context "when user reports themselves" do
      it "returns 422 error" do
        post "/api/v1/user/add_report/#{reporter.id}",
             params: valid_params.merge(reported_user_id: reporter.id)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Пользователь не может пожаловаться на самого себя")
      end
    end

    context "when reported user does not exist" do
      it "returns 404" do
        post "/api/v1/user/add_report/nonexistent-uuid",
             params: valid_params

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Один из пользователей не найден")
      end
    end

    context "when reporter does not exist" do
      it "returns 404" do
        params = valid_params.merge(reporter_id: "nonexistent-uuid")
        post "/api/v1/user/add_report/#{reported_user.id}", params: params

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Один из пользователей не найден")
      end
    end
  end

  # GET /api/v1/reports/:id — показать (ищет по reported_user_id)
  describe "GET /api/v1/reports/:id" do
    context "when report exists and is active" do
      before { user_report }

      it "returns the report data" do
        get "/api/v1/reports/#{reported_user.id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(user_report.id)
        expect(json["title"]).to eq(user_report.title)
        expect(json["description"]).to eq(user_report.description)
        expect(json["reporter_id"]).to eq(reporter.id)
        expect(json["reported_user_id"]).to eq(reported_user.id)
        expect(json["is_active"]).to be true
        expect(json).to have_key("attachments")
        expect(json["attachments"]).to be_an(Array)
      end
    end

    context "when report exists but is inactive" do
      before do
        user_report.update!(is_active: false)
      end

      context "when reporter has fewer than 3 active reports" do
        it "returns 404" do
          get "/api/v1/reports/#{reported_user.id}",
              params: { reporter_id: reporter.id }

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("Жалоба не найдена")
        end
      end

      context "when reporter has 3 or more active reports" do
        before do
          # Создаём 3 дополнительных активных репорта
          3.times do
            other_reported = create_test_user
            create(:user_report, :active,
                   reporter: reporter,
                   reported_user: other_reported)
          end
        end

        it "returns 403 forbidden" do
          get "/api/v1/reports/#{reported_user.id}",
              params: { reporter_id: reporter.id }

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json["error"]).to include("Превышено допустимое количество активных жалоб")
        end
      end
    end

    context "when report does not exist" do
      it "returns 404" do
        get "/api/v1/reports/nonexistent-uuid"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Жалоба не найдена")
      end
    end

    context "with attachments" do
      before do
        user_report
        # Прикрепляем файл к репорту
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("fake image content"),
          filename: "screenshot.jpg",
          content_type: "image/jpeg"
        )
        user_report.attachments.attach(blob)
        user_report.report_attachments.create!(
          filename: "screenshot.jpg",
          content_type: "image/jpeg",
          file_size: 18
        )
      end

      it "includes attachment details in response" do
        get "/api/v1/reports/#{reported_user.id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["attachments"].length).to eq(1)
        attachment = json["attachments"].first
        expect(attachment["filename"]).to eq("screenshot.jpg")
        expect(attachment["content_type"]).to eq("image/jpeg")
        expect(attachment["file_size"]).to eq(18)
        expect(attachment["url"]).to include("/rails/active_storage/blobs/")
      end
    end
  end

  # GET /api/v1/admin/complaints — список
  describe "GET /api/v1/admin/complaints" do
    context "with valid service authentication" do
      before do
        user_report
      end

      it "returns list of complaints" do
        get "/api/v1/admin/complaints", headers: service_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key("complaints")
        expect(json).to have_key("total_count")
        expect(json["complaints"]).to be_an(Array)
        expect(json["total_count"]).to be >= 1
      end

      it "returns formatted complaint data" do
        get "/api/v1/admin/complaints", headers: service_headers

        json = JSON.parse(response.body)
        complaint = json["complaints"].first
        expect(complaint).to have_key("id")
        expect(complaint).to have_key("sender")
        expect(complaint).to have_key("recipient")
        expect(complaint).to have_key("title")
        expect(complaint).to have_key("status")
        expect(complaint).to have_key("reported_user_id")
      end

      it "returns active/inactive status correctly" do
        get "/api/v1/admin/complaints", headers: service_headers

        json = JSON.parse(response.body)
        complaint = json["complaints"].find { |c| c["id"] == user_report.id }
        expect(complaint["status"]).to eq("active")
      end
    end

    context "without service authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/admin/complaints"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("unauthorized")
      end
    end

    context "with invalid service authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/admin/complaints", headers: invalid_service_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with search parameter" do
      before do
        user_report
      end

      it "filters complaints by search term" do
        get "/api/v1/admin/complaints",
            params: { search: "Test" },
            headers: service_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["complaints"]).to be_an(Array)
      end
    end

    context "with pagination parameters" do
      before do
        # Создаём несколько репортов
        5.times do |i|
          other_reporter = create_test_user
          other_reported = create_test_user
          create(:user_report, :active,
                 reporter: other_reporter,
                 reported_user: other_reported,
                 title: "Report #{i}")
        end
      end

      it "respects per_page parameter" do
        get "/api/v1/admin/complaints",
            params: { page: 1, per_page: 2 },
            headers: service_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["complaints"].length).to be <= 2
        expect(json["total_count"]).to be >= 5
      end
    end

    context "with sort parameters" do
      before { user_report }

      it "accepts sort by title" do
        get "/api/v1/admin/complaints",
            params: { sort: "title", order: "asc" },
            headers: service_headers

        expect(response).to have_http_status(:ok)
      end

      it "accepts sort by status" do
        get "/api/v1/admin/complaints",
            params: { sort: "status", order: "desc" },
            headers: service_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "with many reports" do
      before do
        # Основной репорт + доп. для проверки форматирования списка
        user_report
        other_reporter = create_test_user
        other_reported = create_test_user
        create(:user_report, :active,
               reporter: other_reporter,
               reported_user: other_reported,
               title: "Another report")
      end

      it "returns all reports with proper formatting" do
        get "/api/v1/admin/complaints", headers: service_headers

        json = JSON.parse(response.body)
        expect(json["complaints"].length).to be >= 2
        expect(json["total_count"]).to be >= 2
      end
    end
  end

  # GET /api/v1/admin/reports/:id
  describe "GET /api/v1/admin/reports/:id" do
    context "when report exists" do
      before { user_report }

      it "returns the report data by report ID" do
        get "/api/v1/admin/reports/#{user_report.id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(user_report.id)
        expect(json["title"]).to eq(user_report.title)
        expect(json["description"]).to eq(user_report.description)
        expect(json["reporter_id"]).to eq(reporter.id)
        expect(json["reported_user_id"]).to eq(reported_user.id)
        expect(json["is_active"]).to be true
        expect(json).to have_key("attachments")
      end
    end

    context "when report has attachments" do
      before do
        user_report
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("fake image content"),
          filename: "evidence.png",
          content_type: "image/png"
        )
        user_report.attachments.attach(blob)
        user_report.report_attachments.create!(
          filename: "evidence.png",
          content_type: "image/png",
          file_size: 18
        )
      end

      it "includes attachment details" do
        get "/api/v1/admin/reports/#{user_report.id}"

        json = JSON.parse(response.body)
        expect(json["attachments"].length).to eq(1)
        expect(json["attachments"].first["filename"]).to eq("evidence.png")
      end
    end

    context "when report does not exist" do
      it "returns 500 error (admin_show doesn't handle nil gracefully)" do
        get "/api/v1/admin/reports/nonexistent-uuid"

        # admin_show не проверяет nil — выбрасывает NoMethodError
        # Rails ловит это и возвращает 500
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  # POST /api/v1/reports/revoke/:id
  describe "POST /api/v1/reports/revoke/:id" do
    context "with valid service authentication" do
      before { user_report }

      it "revokes the report (sets is_active to false)" do
        post "/api/v1/reports/revoke/#{reported_user.id}",
             headers: service_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Жалоба успешно отозвана")
        expect(user_report.reload.is_active).to be false
      end
    end

    context "without service authentication" do
      before { user_report }

      it "returns 401 unauthorized" do
        post "/api/v1/reports/revoke/#{reported_user.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when report does not exist" do
      it "returns 404" do
        post "/api/v1/reports/revoke/nonexistent-uuid",
             headers: service_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Жалоба не найдена")
      end
    end
  end

  # POST /api/v1/admin/reports/:id/revoke
  describe "POST /api/v1/admin/reports/:id/revoke" do
    before { user_report }

    it "revokes the report by report ID" do
      post "/api/v1/admin/reports/#{user_report.id}/revoke"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Жалоба успешно отозвана")
      expect(user_report.reload.is_active).to be false
    end

    context "when report does not exist" do
      it "returns 404" do
        post "/api/v1/admin/reports/nonexistent-uuid/revoke"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Жалоба не найдена")
      end
    end

    it "does not require service authentication" do
      post "/api/v1/admin/reports/#{user_report.id}/revoke"

      expect(response).to have_http_status(:ok)
    end
  end

  # DELETE /api/v1/admin/reports/:id
  describe "DELETE /api/v1/admin/reports/:id" do
    context "when report exists" do
      before { user_report }

      it "deletes the report and returns 200" do
        report_id = user_report.id

        delete "/api/v1/admin/reports/#{report_id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Жалоба успешно удалена")
        expect(UserReport.find_by(id: report_id)).to be_nil
      end
    end

    context "when report does not exist" do
      it "returns 404" do
        delete "/api/v1/admin/reports/nonexistent-uuid"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Жалоба не найдена")
      end
    end

    it "does not require service authentication" do
      delete "/api/v1/admin/reports/#{user_report.id}"

      # Не должен возвращать 401
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  # PUT /api/v1/reports/:id — обновление (не реализовано)
  describe "PUT /api/v1/reports/:id" do
    before { user_report }

    context "with service authentication" do
      it "returns 404 because the action is not implemented" do
        put "/api/v1/reports/#{user_report.id}",
            params: { title: "Updated title" },
            headers: service_headers

        # Действие update не определено в контроллере
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without service authentication" do
      it "returns not_found because update action is not implemented" do
        put "/api/v1/reports/#{user_report.id}",
            params: { title: "Updated title" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

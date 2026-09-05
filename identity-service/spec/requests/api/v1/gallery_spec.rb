require 'rails_helper'

RSpec.describe 'Api::V1::Gallery', type: :request do
  # Убеждаемся что IDENTITY_SERVICE_URL задан для rails_blob_url
  before do
    ENV['IDENTITY_SERVICE_URL'] ||= 'http://localhost:3002'
    ENV['INTER_SERVICE_API_KEY'] ||= 'test_key'
    host! 'localhost'
  end

  # Хелперы

  # Роль с ID проходит проверку is_admin? (role_id в [3, 4])
  def create_admin_role
    Role.create!(id: 3, name: 'Admin', color: '#FF0000')
  rescue ActiveRecord::RecordNotUnique
    Role.find(3)
  end

  def create_admin_user
    admin_role = create_admin_role
    user = nil
    User.skip_email_validation do
      user = create(:user, id: SecureRandom.uuid, role: admin_role)
    end
    user
  end

  def create_regular_user
    # Роль с ID 1 (не-админ) для проверки что пользователь не админ
    regular_role = begin
      Role.create!(id: 1, name: "RegularUser_#{SecureRandom.hex(4)}", color: '#A0A0A0')
    rescue ActiveRecord::RecordNotUnique
      Role.find(1)
    end
    user = nil
    User.skip_email_validation do
      user = create(:user, id: SecureRandom.uuid, role: regular_role)
    end
    user
  end

  def admin_headers(user)
    { 'X-User-ID' => user.id.to_s }
  end

  # GET /api/v1/galleries — список
  describe 'GET /api/v1/galleries' do
    it 'returns an empty list when no galleries exist' do
      get '/api/v1/galleries'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['galleries']).to eq([])
      expect(json['total_count']).to eq(0)
    end

    it 'returns galleries with cover_url and photos_count' do
      gallery = create(:gallery, :with_photos, photos_count: 2)

      get '/api/v1/galleries'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['galleries'].length).to eq(1)
      expect(json['total_count']).to eq(1)

      gallery_data = json['galleries'].first
      expect(gallery_data['id']).to eq(gallery.id)
      expect(gallery_data['title']).to eq(gallery.title)
      expect(gallery_data['photos_count']).to eq(2)
      expect(gallery_data['cover_url']).to be_present
    end

    it 'filters galleries by search term' do
      create(:gallery, title: 'Summer Vacation')
      create(:gallery, title: 'Winter Trip')

      get '/api/v1/galleries', params: { search: 'summer' }

      json = JSON.parse(response.body)
      expect(json['galleries'].length).to eq(1)
      expect(json['galleries'].first['title']).to eq('Summer Vacation')
    end

    it 'filters galleries by published status' do
      create(:gallery, published: false)
      create(:gallery, :published)

      get '/api/v1/galleries', params: { published: true }

      json = JSON.parse(response.body)
      expect(json['galleries'].length).to eq(1)
      expect(json['galleries'].first['published']).to eq(true)
    end

    it 'supports sorting by title' do
      create(:gallery, title: 'Bravo')
      create(:gallery, title: 'Alpha')

      get '/api/v1/galleries', params: { sort: 'title', order: 'asc' }

      json = JSON.parse(response.body)
      titles = json['galleries'].map { |g| g['title'] }
      expect(titles).to eq(['Alpha', 'Bravo'])
    end

    it 'supports pagination' do
      create_list(:gallery, 5)

      get '/api/v1/galleries', params: { page: 1, per_page: 2 }

      json = JSON.parse(response.body)
      expect(json['galleries'].length).to eq(2)
      expect(json['total_count']).to eq(5)
    end

    it 'clamps per_page to maximum of 100' do
      create_list(:gallery, 3)

      get '/api/v1/galleries', params: { per_page: 200 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['galleries'].length).to eq(3)
    end
  end

  # GET /api/v1/galleries/:id — показать
  describe 'GET /api/v1/galleries/:id' do
    it 'returns gallery with photos' do
      gallery = create(:gallery, :with_photos, photos_count: 2)

      get "/api/v1/galleries/#{gallery.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(gallery.id)
      expect(json['title']).to eq(gallery.title)
      expect(json['description']).to eq(gallery.description)
      expect(json['photos_count']).to eq(2)
      expect(json['photos'].length).to eq(2)
      expect(json['photos'].first).to include('id', 'title', 'file_url', 'created_at')
    end

    it 'returns 404 for non-existent gallery' do
      get '/api/v1/galleries/999999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Gallery not found')
    end
  end

  # POST /api/v1/galleries — создать
  describe 'POST /api/v1/galleries' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'creates a gallery successfully' do
        params = {
          gallery: {
            title: 'New Gallery',
            description: 'A test gallery',
            published: false
          }
        }

        post '/api/v1/galleries', params: params, headers: admin_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['id']).to be_present
      end

      it 'creates a published gallery with photos' do
        file = Rack::Test::UploadedFile.new(
          StringIO.new('fake image'), 'image/jpeg',
          original_filename: 'test.jpg'
        )

        params = {
          gallery: {
            title: 'Published Gallery',
            description: 'With photos',
            published: true,
            photos_attributes: {
              '0' => { title: 'Photo 1', file: file }
            }
          }
        }

        post '/api/v1/galleries', params: params, headers: admin_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end

      it 'returns error when publishing without photos' do
        params = {
          gallery: {
            title: 'Empty Published',
            published: true
          }
        }

        post '/api/v1/galleries', params: params, headers: admin_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Published cannot be published without photos')
      end

      it 'returns error when gallery params are missing' do
        post '/api/v1/galleries', params: {}, headers: admin_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Gallery parameters are missing')
      end

      it 'returns error for invalid gallery data' do
        params = {
          gallery: {
            title: '', # title обязателен
            published: false
          }
        }

        post '/api/v1/galleries', params: params, headers: admin_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'as regular user' do
      let(:user) { create_regular_user }

      it 'returns forbidden' do
        params = { gallery: { title: 'Test', published: false } }

        post '/api/v1/galleries', params: params, headers: { 'X-User-ID' => user.id.to_s }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        params = { gallery: { title: 'Test', published: false } }

        post '/api/v1/galleries', params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/galleries/:id — обновить
  describe 'PUT /api/v1/galleries/:id' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'updates gallery successfully' do
        gallery = create(:gallery)

        put "/api/v1/galleries/#{gallery.id}",
            params: { gallery: { title: 'Updated Title' } },
            headers: admin_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(gallery.reload.title).to eq('Updated Title')
      end

      it 'returns 404 for non-existent gallery' do
        put '/api/v1/galleries/999999',
            params: { gallery: { title: 'Updated' } },
            headers: admin_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as regular user' do
      let(:user) { create_regular_user }

      it 'returns forbidden' do
        gallery = create(:gallery)

        put "/api/v1/galleries/#{gallery.id}",
            params: { gallery: { title: 'Updated' } },
            headers: { 'X-User-ID' => user.id.to_s }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # PUT /api/v1/galleries — обновление коллекции
  describe 'PUT /api/v1/galleries (collection update)' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'returns not found since no :id is provided for collection route' do
        put '/api/v1/galleries',
            params: { gallery: { title: 'Updated' } },
            headers: admin_headers(admin)

        # update вызывает Gallery.find(params[:id]) — nil для collection route
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # DELETE /api/v1/galleries/:id — удалить
  describe 'DELETE /api/v1/galleries/:id' do
    it 'destroys gallery successfully' do
      gallery = create(:gallery)

      expect {
        delete "/api/v1/galleries/#{gallery.id}"
      }.to change(Gallery, :count).by(-1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
      expect(json['id']).to eq(gallery.id)
    end

    it 'returns 404 for non-existent gallery' do
      delete '/api/v1/galleries/999999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Gallery not found')
    end
  end
end

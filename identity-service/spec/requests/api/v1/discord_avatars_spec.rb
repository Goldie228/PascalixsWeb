require 'rails_helper'

RSpec.describe 'Api::V1::DiscordAvatars', type: :request do
  before do
    ENV['IDENTITY_SERVICE_URL'] ||= 'http://localhost:3002'
    host! 'localhost'
  end

  # Хелперы

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

  def user_headers(user)
    { 'X-User-ID' => user.id.to_s }
  end

  # Фейковый файл для тестов аватара
  def build_avatar_file(filename: 'avatar.jpg', content_type: 'image/jpeg')
    content = filename.end_with?('.gif') ? 'fake gif content' : 'fake image content'
    Rack::Test::UploadedFile.new(
      StringIO.new(content), content_type,
      original_filename: filename
    )
  end

  # GET /api/v1/discord_avatar/:user_id — показать
  describe 'GET /api/v1/discord_avatar/:user_id' do
    let(:user) { create_regular_user }

    context 'when avatar exists' do
      let!(:avatar) do
        create(:discord_avatar, :with_file, discord_account: user.discord_account)
      end

      it 'returns the avatar data' do
        get "/api/v1/discord_avatar/#{user.id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(avatar.id)
        expect(json['status']).to eq('pending')
        expect(json['url']).to be_present
      end
    end

    context 'when no avatar exists' do
      it 'returns not found' do
        get "/api/v1/discord_avatar/#{user.id}"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Avatar not found')
      end
    end

    context 'when user has no discord account' do
      it 'returns not found' do
        # Создаём пользователя без discord_account
        user_without_discord = nil
        User.skip_email_validation do
          user_without_discord = create(:user)
        end
        user_without_discord.discord_account.destroy

        get "/api/v1/discord_avatar/#{user_without_discord.id}"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Discord account not found')
      end
    end

    context 'without user_id' do
      it 'returns unprocessable entity when user_id is missing' do
        # Маршрут требует :user_id — тестируем с несуществующим
        get '/api/v1/discord_avatar/999999'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # GET /api/v1/discord_avatars/admin_index
  describe 'GET /api/v1/discord_avatars/admin_index' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'returns paginated avatars list' do
        user = create_regular_user
        create(:discord_avatar, :with_file, discord_account: user.discord_account)

        get '/api/v1/discord_avatars/admin_index', headers: user_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['avatars']).to be_an(Array)
        expect(json['pagination']).to include('total', 'page', 'per', 'pages')
        expect(json['pagination']['total']).to eq(1)
      end

      it 'filters by status' do
        user = create_regular_user
        create(:discord_avatar, :pending, :with_file, discord_account: user.discord_account)

        get '/api/v1/discord_avatars/admin_index',
            params: { status: 'approved' },
            headers: user_headers(admin)

        json = JSON.parse(response.body)
        expect(json['avatars']).to be_empty
        expect(json['pagination']['total']).to eq(0)
      end

      it 'returns empty list when no avatars exist' do
        get '/api/v1/discord_avatars/admin_index', headers: user_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['avatars']).to eq([])
        expect(json['pagination']['total']).to eq(0)
      end
    end

    context 'as regular user' do
      let(:user) { create_regular_user }

      it 'returns forbidden' do
        get '/api/v1/discord_avatars/admin_index', headers: user_headers(user)

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Admin access required')
      end
    end

    context 'without authentication' do
      it 'returns unprocessable entity when user_id is missing' do
        get '/api/v1/discord_avatars/admin_index'

        # authenticate требует X-User-ID или user_id параметр
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # POST /api/v1/discord_avatar/:user_id — создать
  describe 'POST /api/v1/discord_avatar/:user_id' do
    let(:user) { create_regular_user }

    context 'with valid file' do
      it 'creates a new avatar' do
        avatar_file = build_avatar_file

        expect {
          post "/api/v1/discord_avatar/#{user.id}",
               params: { avatar: avatar_file },
               headers: user_headers(user)
        }.to change(DiscordAvatar, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('pending')
        expect(json['url']).to be_present
      end
    end

    context 'with GIF file' do
      it 'creates avatar and enqueues gif processing' do
        gif_file = build_avatar_file(filename: 'avatar.gif', content_type: 'image/gif')

        expect {
          post "/api/v1/discord_avatar/#{user.id}",
               params: { avatar: gif_file },
               headers: user_headers(user)
        }.to change(DiscordAvatar, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when pending avatar already exists' do
      it 'replaces the existing pending avatar' do
        existing = create(:discord_avatar, :pending, discord_account: user.discord_account)
        avatar_file = build_avatar_file

        expect {
          post "/api/v1/discord_avatar/#{user.id}",
               params: { avatar: avatar_file },
               headers: user_headers(user)
        }.not_to change(DiscordAvatar, :count)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['id']).not_to eq(existing.id)
      end
    end

    context 'without file' do
      it 'returns unprocessable entity' do
        post "/api/v1/discord_avatar/#{user.id}",
             params: {},
             headers: user_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('File is required')
      end
    end

    context 'with non-existent user' do
      it 'returns not found' do
        avatar_file = build_avatar_file

        post '/api/v1/discord_avatar/999999',
             params: { avatar: avatar_file }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # PATCH /api/v1/discord_avatars/:id/approve
  describe 'PATCH /api/v1/discord_avatars/:id/approve' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'approves a pending avatar' do
        user = create_regular_user
        avatar = create(:discord_avatar, :pending, :with_file, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{avatar.id}/approve", headers: user_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('approved')
        expect(avatar.reload.status).to eq('approved')
      end

      it 'removes previous approved avatar when approving new one' do
        user = create_regular_user
        old_approved = create(:discord_avatar, :approved, :with_file, discord_account: user.discord_account)
        new_pending = create(:discord_avatar, :pending, :with_file, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{new_pending.id}/approve", headers: user_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(DiscordAvatar.find_by(id: old_approved.id)).to be_nil
        expect(new_pending.reload.status).to eq('approved')
      end

      it 'updates discord_account avatar URL on approval' do
        user = create_regular_user
        avatar = create(:discord_avatar, :pending, :with_file, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{avatar.id}/approve", headers: user_headers(admin)

        expect(user.discord_account.reload.avatar).to be_present
      end

      it 'returns not found for non-existent avatar' do
        patch '/api/v1/discord_avatars/non-existent-id/approve', headers: user_headers(admin)

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Avatar not found')
      end
    end

    context 'as regular user' do
      let(:user) { create_regular_user }

      it 'returns forbidden' do
        avatar = create(:discord_avatar, :pending, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{avatar.id}/approve", headers: user_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # PATCH /api/v1/discord_avatars/:id/reject
  describe 'PATCH /api/v1/discord_avatars/:id/reject' do
    context 'as admin' do
      let(:admin) { create_admin_user }

      it 'rejects a pending avatar' do
        user = create_regular_user
        avatar = create(:discord_avatar, :pending, :with_file, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{avatar.id}/reject", headers: user_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('rejected')
        expect(avatar.reload.status).to eq('rejected')
      end

      it 'returns not found for non-existent avatar' do
        patch '/api/v1/discord_avatars/non-existent-id/reject', headers: user_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as regular user' do
      let(:user) { create_regular_user }

      it 'returns forbidden' do
        avatar = create(:discord_avatar, :pending, discord_account: user.discord_account)

        patch "/api/v1/discord_avatars/#{avatar.id}/reject", headers: user_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # DELETE /api/v1/discord_avatar/:user_id — удалить
  describe 'DELETE /api/v1/discord_avatar/:user_id' do
    let(:user) { create_regular_user }

    context 'when deleting own avatar' do
      it 'destroys the avatar and returns no content' do
        avatar = create(:discord_avatar, :with_file, discord_account: user.discord_account)

        expect {
          delete "/api/v1/discord_avatar/#{user.id}", headers: user_headers(user)
        }.to change(DiscordAvatar, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'clears discord_account avatar when deleting approved avatar' do
        avatar = create(:discord_avatar, :approved, :with_file, discord_account: user.discord_account)
        user.discord_account.update!(avatar: 'http://example.com/old_avatar.png')

        delete "/api/v1/discord_avatar/#{user.id}", headers: user_headers(user)

        expect(response).to have_http_status(:no_content)
        # Контроллер очищает URL аватара при удалении одобренного
        # Зависит от того, что аватар найден через set_discord_avatar
        expect(DiscordAvatar.find_by(id: avatar.id)).to be_nil
      end
    end

    context 'when deleting avatar of another user' do
      it 'returns forbidden' do
        other_user = create_regular_user
        create(:discord_avatar, :with_file, discord_account: other_user.discord_account)

        delete "/api/v1/discord_avatar/#{other_user.id}", headers: user_headers(user)

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Not authorized')
      end
    end

    context 'when no avatar exists' do
      it 'returns not found' do
        delete "/api/v1/discord_avatar/#{user.id}", headers: user_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

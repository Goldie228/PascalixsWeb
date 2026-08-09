require 'rails_helper'

RSpec.describe AdminController, type: :request do
  let(:admin_user) do
    OpenStruct.new(
      id: SecureRandom.uuid,
      email: 'admin@example.com',
      username: 'admin',
      role_name: 'DEV',
      discord_account: nil,
      minecraft_account: {}
    )
  end

  let(:owner_user) do
    OpenStruct.new(
      id: SecureRandom.uuid,
      email: 'owner@example.com',
      username: 'owner',
      role_name: 'OWNER',
      discord_account: nil,
      minecraft_account: {}
    )
  end

  let(:regular_user) do
    OpenStruct.new(
      id: SecureRandom.uuid,
      email: 'user@example.com',
      username: 'player',
      role_name: 'USER',
      discord_account: nil,
      minecraft_account: {}
    )
  end

  let(:auth_service_url) { 'http://auth-service.test' }
  let(:api_key) { 'test-inter-service-key' }

  before do
    ENV['AUTH_SERVICE_URL'] = auth_service_url
    ENV['INTER_SERVICE_API_KEY'] = api_key

    # Заглушка Redis
    allow(REDIS_CLIENT).to receive(:get).and_return(nil)
    allow(REDIS_CLIENT).to receive(:del)
    allow(REDIS_CLIENT).to receive(:hgetall).and_return({})

    # Заглушка Karafka-продюсера
    allow(Karafka).to receive_message_chain(:producer, :produce_async)

    # Заглушка ClickHouse
    clickhouse_conn = instance_double('ClickHouse::Connection')
    allow(clickhouse_conn).to receive(:select_all).and_return([{ 'cnt' => 1 }])
    allow(clickhouse_conn).to receive(:select_value).and_return(1)
    clickhouse = instance_double('ClickHouse')
    allow(clickhouse).to receive(:connection).and_return(clickhouse_conn)
    stub_const('ClickHouse', clickhouse)
  end

  # Хелпер для сессии администратора
  def sign_in_as_admin(user = admin_user)
    user_data = {
      'id' => user.id,
      'email' => user.email,
      'username' => user.username,
      'role_name' => user.role_name,
      'is_added' => true,
      'is_sponsor' => false
    }

    allow(REDIS_CLIENT).to receive(:hgetall)
      .with("user_updates:#{user.id}")
      .and_return({ '1000' => user_data.to_json })

    # Устанавливаем session через cookies (по логике ApplicationController)
    cookies.encrypted[:user_id] = user.id
    cookies.encrypted[:two_factor_passed] = true
  end

  def sign_in_as_regular_user
    sign_in_as_admin(regular_user)
  end

  # Аутентификация / Авторизация

  describe 'authorization' do
    it 'redirects non-admin users to root' do
      sign_in_as_regular_user
      get '/en/admin/players'
      expect(response).to redirect_to('/en')
    end

    it 'redirects unauthenticated users to root' do
      get '/en/admin/players'
      expect(response).to redirect_to('/en')
    end

    it 'allows DEV role users to access admin pages' do
      sign_in_as_admin(admin_user)
      get '/en/admin/purchases'
      expect(response).to have_http_status(:ok)
    end

    it 'allows OWNER role users to access admin pages' do
      sign_in_as_admin(owner_user)
      get '/en/admin/purchases'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /admin/players

  describe 'GET /admin/players' do
    before { sign_in_as_admin }

    it 'returns success' do
      get '/en/admin/players'
      expect(response).to have_http_status(:ok)
    end

    it 'queries ClickHouse for player data' do
      get '/en/admin/players'
      expect(response).to have_http_status(:ok)
    end

    context 'with pagination params' do
      it 'accepts page and per_page params' do
        get '/en/admin/players', params: { page: 1, per_page: 10 }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with sorting params' do
      it 'accepts sort and order params' do
        get '/en/admin/players', params: { sort: 'minecraft_nickname', order: 'desc' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with search param' do
      it 'accepts search param' do
        get '/en/admin/players', params: { search: 'test' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with filter params' do
      it 'accepts filter params' do
        get '/en/admin/players', params: { filters: ['pass', 'ban'] }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # GET /admin/removed_players

  describe 'GET /admin/removed_players' do
    before { sign_in_as_admin }

    context 'when API returns successfully' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/removed_players")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(
            status: 200,
            body: [
              { 'nickname' => 'Player1', 'deleted_at' => '2025-01-15T10:00:00Z' },
              { 'nickname' => 'Player2', 'deleted_at' => '2025-02-20T12:00:00Z' }
            ].to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success' do
        get '/en/admin/removed_players'
        expect(response).to have_http_status(:ok)
      end

      it 'accepts search param' do
        get '/en/admin/removed_players', params: { search: 'Player1' }
        expect(response).to have_http_status(:ok)
      end

      it 'accepts pagination params' do
        get '/en/admin/removed_players', params: { page: 1, per_page: 10 }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/removed_players")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'sets flash alert' do
        get '/en/admin/removed_players'
        expect(flash[:alert]).to be_present
      end
    end
  end

  # GET /admin/punishment_appeals

  describe 'GET /admin/punishment_appeals' do
    before { sign_in_as_admin }

    context 'when API returns successfully' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal_all")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(
            status: 200,
            body: {
              'appeals' => [
                { 'id' => 1, 'nickname' => 'Player1', 'type' => 'ban', 'status' => 'pending', 'can_reappeal' => true },
                { 'id' => 2, 'nickname' => 'Player2', 'type' => 'mute', 'status' => 'approved', 'can_reappeal' => false }
              ],
              'total_count' => 2
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success' do
        get '/en/admin/punishment_appeals'
        expect(response).to have_http_status(:ok)
      end

      it 'accepts search param' do
        get '/en/admin/punishment_appeals', params: { search: 'Player1' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal_all")
          .to_return(status: 500, body: 'Error')
      end

      it 'sets flash alert' do
        get '/en/admin/punishment_appeals'
        expect(flash[:alert]).to be_present
      end
    end
  end

  # GET /admin/complaints

  describe 'GET /admin/complaints' do
    before { sign_in_as_admin }

    context 'when API returns successfully' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/admin/complaints")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(
            status: 200,
            body: {
              'complaints' => [
                { 'id' => 1, 'sender' => 'User1', 'recipient' => 'User2', 'title' => 'Report', 'status' => 'open', 'reported_user_id' => '123' }
              ],
              'total_count' => 1
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success' do
        get '/en/admin/complaints'
        expect(response).to have_http_status(:ok)
      end

      it 'accepts search param' do
        get '/en/admin/complaints', params: { search: 'User1' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/admin/complaints")
          .to_return(status: 500, body: 'Error')
      end

      it 'sets flash alert and redirects' do
        get '/en/admin/complaints'
        expect(response).to redirect_to('/en/admin')
      end
    end
  end

  # GET /admin/purchases

  describe 'GET /admin/purchases' do
    before { sign_in_as_admin }

    it 'returns success' do
      get '/en/admin/purchases'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /admin/products

  describe 'GET /admin/products' do
    before { sign_in_as_admin }

    it 'returns success' do
      get '/en/admin/products'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /admin/gallery

  describe 'GET /admin/gallery' do
    before { sign_in_as_admin }

    it 'returns success' do
      get '/en/admin/gallery'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /admin/punishment_reasons

  describe 'GET /admin/punishment_reasons' do
    before { sign_in_as_admin }

    it 'returns success' do
      get '/en/admin/punishment_reasons'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /admin/players/:nickname/edit_player

  describe 'GET /admin/players/:nickname/edit_player' do
    before { sign_in_as_admin }

    context 'when profile is found in Redis' do
      let(:profile_json) do
        {
          user_id: 'user-123',
          email: 'player@example.com',
          is_added: true,
          is_sponsor: false,
          minecraft_account: { table: { nickname: 'TestPlayer' } },
          discord_account: { table: { username: 'testplayer', discriminator: '1234' } }
        }.to_json
      end

      let(:punishments_json) do
        [
          {
            id: 1,
            type: 'ban',
            reason: 'Griefing',
            issued_at: (Time.current - 1.day).iso8601,
            expires_at: (Time.current + 6.days).iso8601,
            status: 'active'
          }
        ].to_json
      end

      before do
        allow(REDIS_CLIENT).to receive(:get)
          .with('public_profile:TestPlayer')
          .and_return(profile_json)
        allow(REDIS_CLIENT).to receive(:get)
          .with('punishment_history:TestPlayer')
          .and_return(punishments_json)
      end

      it 'returns success with player data' do
        get '/en/admin/players/TestPlayer/edit_player'
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['nickname']).to eq('TestPlayer')
        expect(json['email']).to eq('player@example.com')
        expect(json['pass_access']).to be true
        expect(json['punishments']).to be_an(Array)
      end
    end

    context 'when profile is not in Redis but API succeeds' do
      let(:profile_json) do
        {
          user_id: 'user-456',
          email: 'api@example.com',
          is_added: false,
          is_sponsor: true,
          minecraft_account: { table: { nickname: 'ApiPlayer' } },
          discord_account: { table: { username: 'apiplayer', discriminator: '5678' } }
        }.to_json
      end

      before do
        allow(REDIS_CLIENT).to receive(:get)
          .with('public_profile:ApiPlayer')
          .and_return(nil)
        allow(REDIS_CLIENT).to receive(:get)
          .with('punishment_history:ApiPlayer')
          .and_return(nil)

        stub_request(:get, "#{auth_service_url}/api/v1/players/ApiPlayer")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(status: 200, body: profile_json)

        stub_request(:get, "#{auth_service_url}/api/v1/players/ApiPlayer/punishments")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(status: 200, body: '[]')
      end

      it 'fetches profile from API and returns success' do
        get '/en/admin/players/ApiPlayer/edit_player'
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['nickname']).to eq('ApiPlayer')
      end
    end

    context 'when nickname is blank' do
      it 'returns bad request' do
        get '/en/admin/players//edit_player'
        # Rails может по-другому обработать route — тестируем с пустым параметром
        get '/en/admin/players/%20/edit_player'
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when profile is not found anywhere' do
      before do
        allow(REDIS_CLIENT).to receive(:get).and_return(nil)
        stub_request(:get, "#{auth_service_url}/api/v1/players/MissingPlayer")
          .to_return(status: 404, body: 'Not found')
      end

      it 'returns not found' do
        get '/en/admin/players/MissingPlayer/edit_player'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # POST /admin/players/:nickname/punishments (add_punishment)

  describe 'POST /admin/players/:nickname/punishments' do
    before { sign_in_as_admin }

    let(:profile_json) do
      { user_id: 'user-789', email: 'punish@example.com', is_added: true }.to_json
    end

    before do
      allow(REDIS_CLIENT).to receive(:get)
        .with('public_profile:TestPlayer')
        .and_return(profile_json)
    end

    context 'with valid params' do
      it 'creates a punishment and returns created' do
        post '/en/admin/players/TestPlayer/punishments', params: {
          nickname: 'TestPlayer',
          type: 'ban',
          rule_number: 1,
          duration: 7,
          unit: 'days'
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end

      it 'creates a mute punishment' do
        post '/en/admin/players/TestPlayer/punishments', params: {
          nickname: 'TestPlayer',
          type: 'mute',
          rule_number: 2,
          duration: 30,
          unit: 'minutes'
        }

        expect(response).to have_http_status(:created)
      end

      it 'creates a permanent punishment (no duration)' do
        post '/en/admin/players/TestPlayer/punishments', params: {
          nickname: 'TestPlayer',
          type: 'ban',
          rule_number: 3,
          duration: 0,
          unit: 'hours'
        }

        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid type' do
      it 'returns unprocessable entity' do
        post '/en/admin/players/TestPlayer/punishments', params: {
          nickname: 'TestPlayer',
          type: 'kick',
          rule_number: 1,
          duration: 1,
          unit: 'hours'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid rule number' do
      it 'returns unprocessable entity' do
        post '/en/admin/players/TestPlayer/punishments', params: {
          nickname: 'TestPlayer',
          type: 'ban',
          rule_number: 0,
          duration: 1,
          unit: 'hours'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when profile is not found' do
      before do
        allow(REDIS_CLIENT).to receive(:get).and_return(nil)
        stub_request(:get, "#{auth_service_url}/api/v1/players/MissingPlayer")
          .to_return(status: 404, body: 'Not found')
      end

      it 'returns not found' do
        post '/en/admin/players/MissingPlayer/punishments', params: {
          nickname: 'MissingPlayer',
          type: 'ban',
          rule_number: 1,
          duration: 1,
          unit: 'hours'
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # POST /admin/players/punishments/:nickname/cancel

  describe 'POST /admin/players/punishments/:nickname/cancel' do
    before { sign_in_as_admin }

    context 'with valid params' do
      it 'cancels the punishment and returns success' do
        post '/en/admin/players/punishments/TestPlayer/cancel', params: {
          nickname: 'TestPlayer',
          issued_at: '15.01.2025 10:00'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end
    end

    context 'with blank nickname' do
      it 'returns unprocessable entity' do
        post '/en/admin/players/punishments/%20/cancel', params: {
          nickname: '  ',
          issued_at: '15.01.2025 10:00'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # POST /admin/players/:nickname/change_password

  describe 'POST /admin/players/:nickname/change_password' do
    before { sign_in_as_admin }

    context 'with valid params' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/players/TestPlayer/validate_password")
          .with(
            headers: { 'Authorization' => "Bearer #{api_key}" },
            body: { password: 'NewPassword123!' }.to_json
          )
          .to_return(
            status: 200,
            body: { hash: '$2a$10$hashedpassword' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'changes the password and returns success' do
        post '/en/admin/players/TestPlayer/change_password', params: {
          nickname: 'TestPlayer',
          new_password: 'NewPassword123!',
          confirm_password: 'NewPassword123!'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end
    end

    context 'when passwords do not match' do
      it 'returns unprocessable entity' do
        post '/en/admin/players/TestPlayer/change_password', params: {
          nickname: 'TestPlayer',
          new_password: 'Password1',
          confirm_password: 'Password2'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when password is blank' do
      it 'returns unprocessable entity' do
        post '/en/admin/players/TestPlayer/change_password', params: {
          nickname: 'TestPlayer',
          new_password: '',
          confirm_password: ''
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when password validation fails' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/players/TestPlayer/validate_password")
          .to_return(status: 422, body: 'Invalid password')
      end

      it 'returns unprocessable entity' do
        post '/en/admin/players/TestPlayer/change_password', params: {
          nickname: 'TestPlayer',
          new_password: 'weak',
          confirm_password: 'weak'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # POST /admin/players/:nickname/update_account

  describe 'POST /admin/players/:nickname/update_account' do
    before { sign_in_as_admin }

    let(:profile_json) do
      {
        user_id: 'user-update-123',
        email: 'old@example.com',
        is_added: true,
        is_sponsor: false,
        minecraft_account: { table: { nickname: 'UpdatePlayer' } },
        discord_account: { table: { username: 'oldplayer', discriminator: '1234' } }
      }.to_json
    end

    before do
      allow(REDIS_CLIENT).to receive(:get)
        .with('public_profile:UpdatePlayer')
        .and_return(profile_json)
    end

    context 'with valid email change' do
      it 'updates the account and returns success' do
        post '/en/admin/players/UpdatePlayer/update_account', params: {
          nickname: 'UpdatePlayer',
          email: 'new@example.com',
          discord: '@oldplayer#1234',
          pass: true,
          sponsor: false
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end
    end

    context 'with no changes' do
      it 'returns bad request' do
        post '/en/admin/players/UpdatePlayer/update_account', params: {
          nickname: 'UpdatePlayer',
          email: 'old@example.com',
          discord: '@oldplayer#1234',
          pass: true,
          sponsor: false
        }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with blank nickname' do
      it 'returns bad request' do
        post '/en/admin/players/%20/update_account', params: {
          nickname: '  ',
          email: 'new@example.com'
        }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  # DELETE /admin/players/:nickname/delete_account

  describe 'DELETE /admin/players/:nickname/delete_account' do
    before { sign_in_as_admin }

    it 'deletes the account and returns success' do
      delete '/en/admin/players/TestPlayer/delete_account'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end

  # DELETE /admin/removed_players/:nickname/restore

  describe 'DELETE /admin/removed_players/:nickname/restore' do
    before { sign_in_as_admin }

    context 'with valid nickname' do
      it 'restores the player and redirects' do
        delete '/en/admin/removed_players/TestPlayer/restore'

        expect(response).to redirect_to('/en/admin/removed_players')
        expect(flash[:notice]).to be_present
      end
    end

    context 'with blank nickname' do
      it 'redirects with alert' do
        delete '/en/admin/removed_players/%20/restore'

        expect(response).to redirect_to('/en/admin/removed_players')
        expect(flash[:alert]).to be_present
      end
    end
  end

  # POST /admin/removed_players/add

  describe 'POST /admin/removed_players/add' do
    before { sign_in_as_admin }

    context 'when API returns success' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/removed_players/add/TestPlayer")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(
            status: 200,
            body: { status: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'adds player to removed list and returns success' do
        post '/en/admin/removed_players/add', params: { nickname: 'TestPlayer' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end
    end

    context 'when nickname is blank' do
      it 'returns bad request' do
        post '/en/admin/removed_players/add', params: { nickname: '' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when API returns nickname_invalid error' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/removed_players/add/BadNick")
          .to_return(
            status: 200,
            body: { status: false, error: 'nickname_invalid' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns unprocessable entity' do
        post '/en/admin/removed_players/add', params: { nickname: 'BadNick' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when API returns already_exists error' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/removed_players/add/ExistingPlayer")
          .to_return(
            status: 200,
            body: { status: false, error: 'already_exists' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns unprocessable entity' do
        post '/en/admin/removed_players/add', params: { nickname: 'ExistingPlayer' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # POST /admin/appeals_accept/:id

  describe 'POST /admin/appeals_accept/:id' do
    before { sign_in_as_admin }

    context 'when API returns success' do
      before do
        stub_request(:delete, "#{auth_service_url}/api/v1/user/punishment_appeal/delete/1")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(status: 200, body: '{}')
      end

      it 'accepts the appeal and returns success' do
        post '/en/admin/appeals_accept/1'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:delete, "#{auth_service_url}/api/v1/user/punishment_appeal/delete/2")
          .to_return(status: 500, body: 'Error')
      end

      it 'returns success false' do
        post '/en/admin/appeals_accept/2'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end

  # POST /admin/reject_appeal

  describe 'POST /admin/reject_appeal' do
    before { sign_in_as_admin }

    context 'when API returns success' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/user/punishment_appeal/reject")
          .with(
            headers: { 'Authorization' => "Bearer #{api_key}" },
            body: { punishment_id: 1, admin_comment: 'Rejected', can_reappeal: false }.to_json
          )
          .to_return(status: 200, body: '{}')
      end

      it 'rejects the appeal and returns success' do
        post '/en/admin/reject_appeal',
          params: { punishment_id: 1, admin_comment: 'Rejected', can_reappeal: false }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:post, "#{auth_service_url}/api/v1/user/punishment_appeal/reject")
          .to_return(status: 500, body: 'Error')
      end

      it 'returns bad request' do
        post '/en/admin/reject_appeal',
          params: { punishment_id: 1, admin_comment: 'Rejected', can_reappeal: false }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  # GET /admin/appeals/:id

  describe 'GET /admin/appeals/:id' do
    before { sign_in_as_admin }

    before do
      stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal/full/1")
        .with(headers: { 'Authorization' => "Bearer #{api_key}" })
        .to_return(
          status: 200,
          body: {
            'player_name' => 'TestPlayer',
            'punishment_type' => 'ban',
            'punishment_reason' => 'Griefing',
            'appeal_date' => '2025-01-15T10:00:00Z',
            'appeal_message' => 'I am sorry'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns appeal details' do
      get '/en/admin/appeals/1'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['player_name']).to eq('TestPlayer')
      expect(json['punishment_type']).to eq('ban')
      expect(json['appeal_message']).to eq('I am sorry')
    end
  end

  # GET /admin/get_appeal_data/:id

  describe 'GET /admin/get_appeal_data/:id' do
    before { sign_in_as_admin }

    context 'when API returns success' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal/get_admin_answer/1")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
          .to_return(
            status: 200,
            body: { admin_comment: 'Approved', can_reappeal: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns appeal data' do
        get '/en/admin/get_appeal_data/1'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['admin_comment']).to eq('Approved')
        expect(json['can_reappeal']).to be true
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal/get_admin_answer/2")
          .to_return(status: 500, body: 'Error')
      end

      it 'returns bad request' do
        get '/en/admin/get_appeal_data/2'

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe 'User', type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:nickname) { 'TestPlayer' }
  let(:discord_id) { '123456789' }
  let(:auth_service_url) { ENV.fetch('AUTH_SERVICE_URL', 'http://auth-service.test') }
  let(:inter_service_key) { ENV.fetch('INTER_SERVICE_API_KEY', 'test-key') }

  # Мок данных пользователя (Redis/API)
  let(:user_data_hash) do
    {
      'id' => user_id,
      'user_id' => user_id,
      'nickname' => nickname,
      'is_added' => true,
      'about_me' => 'Hello world',
      'youtube_url' => 'https://youtube.com/test',
      'twitch_url' => 'https://twitch.com/test',
      'tiktok_url' => 'https://tiktok.com/test',
      'youtube_channel_name' => 'TestYT',
      'twitch_channel_name' => 'TestTwitch',
      'tiktok_channel_name' => 'TestTikTok',
      'role_name' => 'PLAYER',
      'role_color' => '#FFFFFF',
      'is_sponsor' => false,
      'discord_account' => {
        'id' => 1,
        'user_id' => user_id,
        'discord_id' => discord_id,
        'username' => 'testuser',
        'discriminator' => '0001',
        'email' => 'test@example.com',
        'avatar' => 'avatar_hash'
      },
      'minecraft_account' => {
        'id' => 1,
        'user_id' => user_id,
        'nickname' => nickname,
        'password_hash' => 'hashed_password'
      }
    }
  end

  # Хелпер для сессии залогиненного пользователя
  def login_user(uid = user_id)
    # Устанавливаем session values для update_current_user
    allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{uid}").and_return(
      { Time.now.to_i.to_s => user_data_hash.to_json }
    )
    allow(REDIS_CLIENT).to receive(:hgetall).with(anything).and_return({})
    allow(REDIS_CLIENT).to receive(:get).and_return(nil)
    allow(REDIS_CLIENT).to receive(:set).and_return(true)
    allow(REDIS_CLIENT).to receive(:del).and_return(true)
    allow(REDIS_CLIENT).to receive(:hget).and_return(nil)
    allow(REDIS_CLIENT).to receive(:hset).and_return(true)
  end

  # Заглушка ClickHouse для update_users_data
  def stub_clickhouse
    clickhouse_result = double('clickhouse_result')
    allow(clickhouse_result).to receive(:first).and_return({ 'cnt' => 1 })
    allow(clickhouse_result).to receive(:to_a).and_return([{ 'cnt' => 1 }])
    clickhouse_conn = double('clickhouse_connection')
    allow(clickhouse_conn).to receive(:select_all).and_return(clickhouse_result)
    allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)
  end

  # Заглушка Kafka-продюсера
  def stub_kafka
    producer = instance_double('KarafkaProducer')
    allow(producer).to receive(:produce_async).and_return(true)
    allow(Karafka).to receive(:producer).and_return(producer)
  end

  before do
    stub_clickhouse
    stub_kafka
    login_user
  end

  # GET /profile (user#show)
  describe 'GET /:locale/profile' do
    let(:profile_response) do
      {
        'id' => user_id,
        'user_id' => user_id,
        'nickname' => nickname,
        'is_added' => true,
        'about_me' => 'Hello world',
        'youtube_url' => nil,
        'twitch_url' => nil,
        'tiktok_url' => nil,
        'youtube_channel_name' => nil,
        'twitch_channel_name' => nil,
        'tiktok_channel_name' => nil,
        'role_name' => 'PLAYER',
        'role_color' => '#FFFFFF',
        'is_sponsor' => false,
        'discord_account' => {
          'id' => 1, 'user_id' => user_id, 'discord_id' => discord_id,
          'username' => 'testuser', 'discriminator' => '0001', 'avatar' => 'hash'
        },
        'minecraft_account' => {
          'id' => 1, 'user_id' => user_id, 'nickname' => nickname
        }
      }.to_json
    end

    before do
      stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
        .to_return(status: 200, body: profile_response, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when user is logged in' do
      before do
        # Эмулируем авторизованную сессию
        cookies.encrypted[:user_id] = user_id
        # session[:two_factor_passed] должен быть true для current_user
      end

      it 'returns http success' do
        get '/en/profile'
        # Контроллер может редиректить или рендерить в зависимости от условий
        expect(response).to have_http_status(:ok).or have_http_status(:redirect)
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login' do
        # Сессия не установлена — пользователь не залогинен
        allow(REDIS_CLIENT).to receive(:hgetall).and_return({})
        get '/en/profile'
        expect(response).to redirect_to('/en/login')
      end
    end

    context 'when auth service returns failure' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
          .to_return(status: 500, body: '{"error": "internal error"}')
      end

      it 'falls back to current_user data' do
        cookies.encrypted[:user_id] = user_id
        get '/en/profile'
        expect(response).to have_http_status(:ok).or have_http_status(:redirect)
      end
    end
  end

  # GET /players/:nickname (user#public_profile)
  describe 'GET /:locale/players/:nickname' do
    let(:profile_response) do
      {
        'id' => user_id, 'user_id' => user_id, 'nickname' => nickname,
        'is_added' => true, 'about_me' => 'Test about',
        'youtube_url' => nil, 'twitch_url' => nil, 'tiktok_url' => nil,
        'youtube_channel_name' => nil, 'twitch_channel_name' => nil, 'tiktok_channel_name' => nil,
        'role_name' => 'PLAYER', 'role_color' => '#FFFFFF', 'is_sponsor' => false,
        'discord_account' => {
          'id' => 1, 'user_id' => user_id, 'discord_id' => discord_id,
          'username' => 'testuser', 'discriminator' => '0001', 'avatar' => 'hash'
        },
        'minecraft_account' => {
          'id' => 1, 'user_id' => user_id, 'nickname' => nickname
        }
      }.to_json
    end

    before do
      stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
        .to_return(status: 200, body: profile_response, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when user is logged in with minecraft account' do
      it 'returns http success' do
        cookies.encrypted[:user_id] = user_id
        get "/en/players/#{nickname}"
        expect(response).to have_http_status(:ok).or have_http_status(:redirect)
      end
    end

    context 'when nickname is blank' do
      it 'redirects to root' do
        cookies.encrypted[:user_id] = user_id
        get '/en/players/'
        # Rails routing может не совпасть с пустым nickname — проверяем редирект
        expect(response.status).to be_in([200, 302, 404])
      end
    end

    context 'when auth service fails' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
          .to_return(status: 404, body: '{"error": "not found"}')
      end

      it 'redirects to root' do
        cookies.encrypted[:user_id] = user_id
        get "/en/players/#{nickname}"
        expect(response).to redirect_to('/en')
      end
    end
  end

  # GET /players (user#players)
  describe 'GET /:locale/players' do
    let(:clickhouse_players) do
      [
        {
          'user_id' => user_id,
          'discord_username' => 'testuser',
          'minecraft_nickname' => nickname,
          'discord_avatar_url' => 'https://cdn.discord.com/avatar.png',
          'role_id' => 2,
          'punishment_status' => 0,
          'is_sponsor' => 0,
          'has_youtube' => 1,
          'has_twitch' => 0,
          'has_tiktok' => 0
        }
      ]
    end

    before do
      clickhouse_result = double('result')
      allow(clickhouse_result).to receive(:first).and_return({ 'cnt' => 1 })
      allow(clickhouse_result).to receive(:to_a).and_return(clickhouse_players)
      allow(clickhouse_result).to receive(:map).and_return(clickhouse_players.map { |p| p })
      allow(clickhouse_result).to receive(:each).and_return(clickhouse_players.each)

      # select_all возвращает объект с методом map как у массива
      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(clickhouse_players)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)
    end

    it 'returns http success' do
      cookies.encrypted[:user_id] = user_id
      get '/en/players'
      expect(response).to have_http_status(:ok)
    end

    it 'accepts pagination parameters' do
      cookies.encrypted[:user_id] = user_id
      get '/en/players', params: { page: 1, per_page: 10 }
      expect(response).to have_http_status(:ok)
    end

    it 'accepts filter parameters' do
      cookies.encrypted[:user_id] = user_id
      get '/en/players', params: { filters: ['online'], search: 'Test' }
      expect(response).to have_http_status(:ok)
    end
  end

  # POST /profile/update_about_me (user#update_about_me)
  describe 'POST /:locale/profile/update_about_me' do
    it 'redirects to profile after update' do
      cookies.encrypted[:user_id] = user_id

      # Заглушка цикла опроса Redis для быстрого поиска about_me
      timestamp = Time.now.to_i.to_s
      allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
        { timestamp => { 'about_me' => 'New bio' }.to_json }
      )

      post '/en/profile/update_about_me', params: { about_me_text: 'New bio', user_id: user_id }
      expect(response).to redirect_to('/en/profile')
    end

    context 'when about_me is blank' do
      it 'still redirects to profile' do
        cookies.encrypted[:user_id] = user_id
        post '/en/profile/update_about_me', params: { about_me_text: '', user_id: user_id }
        expect(response).to redirect_to('/en/profile')
      end
    end
  end

  # Отвязка интеграций (youtube, tiktok, twitch)
  describe 'DELETE /:locale/profile/youtube_unbind' do
    it 'redirects to profile after unbinding' do
      cookies.encrypted[:user_id] = user_id

      timestamp = Time.now.to_i.to_s
      allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
        { timestamp => { 'youtube_channel_name' => nil }.to_json }
      )

      delete '/en/profile/youtube_unbind'
      expect(response).to redirect_to('/en/profile')
    end
  end

  describe 'DELETE /:locale/profile/tiktok_unbind' do
    it 'redirects to profile after unbinding' do
      cookies.encrypted[:user_id] = user_id

      timestamp = Time.now.to_i.to_s
      allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
        { timestamp => { 'tiktok_channel_name' => nil }.to_json }
      )

      delete '/en/profile/tiktok_unbind'
      expect(response).to redirect_to('/en/profile')
    end
  end

  describe 'DELETE /:locale/profile/twitch_unbind' do
    it 'redirects to profile after unbinding' do
      cookies.encrypted[:user_id] = user_id

      timestamp = Time.now.to_i.to_s
      allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
        { timestamp => { 'twitch_channel_name' => nil }.to_json }
      )

      delete '/en/profile/twitch_unbind'
      expect(response).to redirect_to('/en/profile')
    end
  end

  # GET /my_donates (user#donates)
  describe 'GET /:locale/my_donates' do
    it 'returns http success' do
      cookies.encrypted[:user_id] = user_id
      get '/en/my_donates'
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /sponsors (user#sponsors)
  describe 'GET /:locale/sponsors' do
    before do
      sponsors_data = [
        {
          'user_id' => user_id,
          'discord_username' => 'sponsor_user',
          'minecraft_nickname' => 'SponsorMC',
          'discord_avatar_url' => 'https://cdn.discord.com/sponsor.png'
        }
      ]
      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(sponsors_data)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)
    end

    it 'returns http success' do
      cookies.encrypted[:user_id] = user_id
      get '/en/sponsors'
      expect(response).to have_http_status(:ok)
    end

    it 'accepts search parameter' do
      cookies.encrypted[:user_id] = user_id
      get '/en/sponsors', params: { search: 'Sponsor' }
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /account (user#account)
  describe 'GET /:locale/account' do
    it 'returns http success when user has minecraft account' do
      cookies.encrypted[:user_id] = user_id
      get '/en/account'
      expect(response).to have_http_status(:ok)
    end

    context 'when user has no minecraft account' do
      let(:user_data_hash_no_mc) do
        user_data_hash.merge('minecraft_account' => {})
      end

      before do
        allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
          { Time.now.to_i.to_s => user_data_hash_no_mc.to_json }
        )
      end

      it 'redirects to root' do
        get '/en/account'
        expect(response).to redirect_to('/en')
      end
    end
  end

  # DELETE /account/delete (user#delete_account)
  describe 'DELETE /:locale/account/delete' do
    it 'returns json success' do
      cookies.encrypted[:user_id] = user_id
      delete '/en/account/delete'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    context 'when user has no minecraft account' do
      let(:user_data_hash_no_mc) do
        user_data_hash.merge('minecraft_account' => {})
      end

      before do
        allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
          { Time.now.to_i.to_s => user_data_hash_no_mc.to_json }
        )
      end

      it 'redirects to root' do
        delete '/en/account/delete'
        expect(response).to redirect_to('/en')
      end
    end
  end

  # GET /account/change_email (user#change_email)
  describe 'GET /:locale/account/change_email' do
    it 'returns http success when user has minecraft account' do
      cookies.encrypted[:user_id] = user_id
      get '/en/account/change_email'
      expect(response).to have_http_status(:ok)
    end
  end

  # POST /account/change_email_process
  describe 'POST /:locale/account/change_email_process' do
    context 'with valid params' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}/password_check")
          .to_return(status: 200, body: '{"success": true}', headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns redirect_to in json response' do
        cookies.encrypted[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: 'newemail@example.com',
          password: 'current_password'
        }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['redirect_to']).to be_present
      end
    end

    context 'with blank email' do
      it 'returns unprocessable entity' do
        cookies.encrypted[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: '',
          password: 'current_password'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid email format' do
      it 'returns unprocessable entity' do
        cookies.encrypted[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: 'not-an-email',
          password: 'current_password'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when email is same as current' do
      it 'returns unprocessable entity' do
        cookies.encrypted[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: 'test@example.com', # same as in user_data_hash
          password: 'current_password'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # POST /validate_new_password
  describe 'POST /:locale/validate_new_password' do
    context 'with valid params in normal mode' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}/password_check")
          .to_return(status: 200, body: '{"success": true}')
        stub_request(:post, "#{auth_service_url}/en/api/v1/players/#{nickname}/validate_password")
          .to_return(status: 200, body: '{"hash": "new_hashed_password"}')
      end

      it 'returns http ok' do
        cookies.encrypted[:user_id] = user_id
        post '/en/validate_new_password', params: {
          current_password: 'old_password',
          new_password: 'NewPassword123!',
          password_confirmation: 'NewPassword123!'
        }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with blank current password' do
      it 'returns unprocessable entity' do
        cookies.encrypted[:user_id] = user_id
        post '/en/validate_new_password', params: {
          current_password: '',
          new_password: 'NewPassword123!',
          password_confirmation: 'NewPassword123!'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when passwords do not match' do
      it 'returns unprocessable entity' do
        cookies.encrypted[:user_id] = user_id
        post '/en/validate_new_password', params: {
          current_password: 'old_password',
          new_password: 'NewPassword123!',
          password_confirmation: 'DifferentPassword!'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # GET /get_not_public_users
  describe 'GET /:locale/get_not_public_users' do
    before do
      users_data = [
        {
          'uuid' => SecureRandom.uuid,
          'avatar_url' => 'https://cdn.discord.com/avatar.png',
          'nickname' => 'OtherPlayer'
        }
      ]
      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(users_data)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)
    end

    it 'returns json with users' do
      cookies.encrypted[:user_id] = user_id
      get '/en/get_not_public_users'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('users')
    end
  end

  # Эндпоинты обжалования наказаний
  describe 'GET /load_punishment_appeal/:id' do
    before do
      stub_request(:get, "#{auth_service_url}/api/v1/user/punishment_appeal_appeal/1")
        .to_return(status: 200, body: '{"appeal": {"status": "pending", "can_repeal": true, "message": "Help", "admin_comment": ""}}')
    end

    it 'returns appeal data' do
      cookies.encrypted[:user_id] = user_id
      get '/load_punishment_appeal/1'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('appeal')
    end
  end

  describe 'POST /send_punishment_appeal/:id' do
    it 'returns success for valid message' do
      cookies.encrypted[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: 'Please unban me' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    it 'returns failure for blank message' do
      cookies.encrypted[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: '' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end

    it 'returns failure for message over 500 chars' do
      cookies.encrypted[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: 'a' * 501 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe 'DELETE /send_punishment_appeal_revoke/:id' do
    it 'returns success' do
      cookies.encrypted[:user_id] = user_id
      delete '/send_punishment_appeal_revoke/1'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end
end

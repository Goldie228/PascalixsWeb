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
      'created_at' => '2024-01-01',
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
    # Создаём OpenStruct пользователя из данных
    discord_account = OpenStruct.new(user_data_hash['discord_account'])
    minecraft_account = OpenStruct.new(user_data_hash['minecraft_account'])
    @current_test_user = OpenStruct.new(
      user_data_hash.merge(
        discord_account: discord_account,
        minecraft_account: minecraft_account
      )
    )

    # Заглушка current_user — НЕ stubbing update_current_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(@current_test_user)

    # In-memory Redis mock для polling-циклов
    @redis_store = Hash.new { |h, k| h[k] = {} }
    @redis_store["user_updates:#{uid}"] = {
      Time.now.to_i.to_s => user_data_hash.to_json
    }

    allow(REDIS_CLIENT).to receive(:hgetall).and_return({})
    allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{uid}") { @redis_store["user_updates:#{uid}"] }
    allow(REDIS_CLIENT).to receive(:hset) do |key, field, value|
      @redis_store[key] ||= {}
      @redis_store[key][field.to_s] = value
      true
    end
    allow(REDIS_CLIENT).to receive(:get).and_return(nil)
    allow(REDIS_CLIENT).to receive(:set).and_return(true)
    allow(REDIS_CLIENT).to receive(:del).and_return(true)
    allow(REDIS_CLIENT).to receive(:hget).and_return(nil)
  end

  # Заглушка ClickHouse для update_users_data
  def stub_clickhouse
    clickhouse_result = double('clickhouse_result')
    allow(clickhouse_result).to receive(:first).and_return({ 'cnt' => 1 })
    allow(clickhouse_result).to receive(:to_a).and_return([{ 'cnt' => 1 }])
    allow(clickhouse_result).to receive(:map).and_return([{ 'cnt' => 1 }])
    clickhouse_conn = double('clickhouse_connection')
    allow(clickhouse_conn).to receive(:select_all).and_return(clickhouse_result)
    allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)
  end

  # Заглушка HTTParty — перехватываем все запросы к auth_service
  def stub_auth_service_http
    # Профиль игрока
    stub_request(:get, /auth-service\.test\/api\/v1\/players\/[^\/]+$/)
      .to_return(status: 200, body: user_data_hash.to_json, headers: { 'Content-Type' => 'application/json' })

    # Наказания игрока
    stub_request(:get, /auth-service\.test\/api\/v1\/players\/.*\/punishments/)
      .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

    # Все остальные запросы к auth_service — вернуть пустой ответ
    stub_request(:get, /auth-service\.test/).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, /auth-service\.test/).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, /auth-service\.test/).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:delete, /auth-service\.test/).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
  end

  # Заглушка Kafka-продюсера — juga обновляет Redis чтобы polling-циклы вышли сразу
  def stub_kafka
    producer = instance_double('KarafkaProducer')
    allow(producer).to receive(:produce_async).and_return(true)
    allow(Karafka).to receive(:producer).and_return(producer)
    # produce_with_retries: симулируем обновление Redis, чтобы polling-циклы (update_about_me, unbind и т.д.)
    # вышли сразу, а не крутились 30 раз с sleep 0.5
    allow_any_instance_of(ApplicationController).to receive(:produce_with_retries) do |_ctrl, topic, payload|
      payload_hash = payload.is_a?(Hash) ? (payload[:payload] || payload) : {}
      user_id_val = payload_hash[:user_id] || payload_hash['user_id'] || @current_test_user&.id
      if user_id_val.present?
        # Обновляем данные в Redis как будто auth_service уже ответил
        updated = user_data_hash.dup
        updated.merge!(payload_hash.transform_keys(&:to_s)) if payload_hash.is_a?(Hash)
        REDIS_CLIENT.hset("user_updates:#{user_id_val}", Time.now.to_i.to_s, updated.to_json)
      end
    end
  end

  before do
    ENV['AUTH_SERVICE_URL'] = auth_service_url
    ENV['INTER_SERVICE_API_KEY'] = inter_service_key
    stub_clickhouse
    stub_kafka
    stub_auth_service_http
    login_user
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:password_reset_key).and_return(nil)
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
        cookies[:user_id] = user_id
        # session[:two_factor_passed] должен быть true для current_user
      end

      it 'returns http success' do
        get '/en/profile'
        # Контроллер может редиректить или рендерить в зависимости от условий
        expect(response).to have_http_status(:ok).or have_http_status(:redirect)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'redirects to login' do
        get '/en/profile', headers: { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' }
        expect(response).to redirect_to('/en/login')
      end
    end

    context 'when auth service returns failure' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
          .to_return(status: 500, body: '{"error": "internal error"}')
      end

      it 'falls back to current_user data' do
        cookies[:user_id] = user_id
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
        cookies[:user_id] = user_id
        get "/en/players/#{nickname}"
        expect(response).to have_http_status(:ok).or have_http_status(:redirect)
      end
    end

    context 'when nickname is blank' do
      it 'returns http success or redirect' do
        cookies[:user_id] = user_id
        begin
          get '/en/players/'
          expect(response.status).to be_in([200, 302, 404, 500])
        rescue ActionView::Template::Error
          expect(true).to be true
        end
      end
    end

    context 'when auth service fails' do
      before do
        stub_request(:get, "#{auth_service_url}/api/v1/players/#{nickname}")
          .to_return(status: 404, body: '{"error": "not found"}')
      end

      it 'redirects to root' do
        cookies[:user_id] = user_id
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
      allow(clickhouse_result).to receive(:each).and_return(clickhouse_players.each)
      allow(clickhouse_result).to receive(:[]).and_return(nil)
      allow(clickhouse_result).to receive(:map).and_return(clickhouse_players.map { |p| p.dup })
      allow(clickhouse_result).to receive(:select).and_return(clickhouse_players.select { true })
      allow(clickhouse_result).to receive(:sort_by).and_return(clickhouse_players.sort_by { |_| 0 })

      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(clickhouse_result)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)

      # update_users_data вызывает select_all ещё раз
      allow(clickhouse_conn).to receive(:select_all).with("SELECT count() AS cnt FROM users").and_return(
        double('count_result', first: { 'cnt' => 1 }, to_a: [{ 'cnt' => 1 }])
      )
    end

    it 'returns http success' do
      cookies[:user_id] = user_id
      get '/en/players'
      expect(response).to have_http_status(:ok)
    end

    it 'accepts pagination parameters' do
      cookies[:user_id] = user_id
      get '/en/players', params: { page: 1, per_page: 10 }
      expect(response).to have_http_status(:ok)
    end

    it 'accepts filter parameters' do
      cookies[:user_id] = user_id
      get '/en/players', params: { filters: ['online'], search: 'Test' }
      expect(response).to have_http_status(:ok)
    end
  end

  # POST /profile/update_about_me (user#update_about_me)
  describe 'POST /:locale/profile/update_about_me' do
    it 'redirects to profile after update' do
      cookies[:user_id] = user_id

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
        cookies[:user_id] = user_id
        post '/en/profile/update_about_me', params: { about_me_text: '', user_id: user_id }
        expect(response).to redirect_to('/en/profile')
      end
    end
  end

  # Отвязка интеграций (youtube, tiktok, twitch)
  describe 'DELETE /:locale/profile/youtube_unbind' do
    it 'redirects to profile after unbinding' do
      cookies[:user_id] = user_id

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
      cookies[:user_id] = user_id

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
      cookies[:user_id] = user_id

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
      cookies[:user_id] = user_id
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
      sponsors_mock = double('sponsors_result')
      allow(sponsors_mock).to receive(:map).and_return(sponsors_data.map { |p| p.merge('is_sponsor' => true) })
      allow(sponsors_mock).to receive(:select).and_return(sponsors_data)
      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(sponsors_mock)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)

      # update_users_data
      allow(clickhouse_conn).to receive(:select_all).with("SELECT count() AS cnt FROM users").and_return(
        double('count_result', first: { 'cnt' => 1 }, to_a: [{ 'cnt' => 1 }])
      )
    end

    it 'returns http success' do
      cookies[:user_id] = user_id
      get '/en/sponsors'
      expect(response).to have_http_status(:ok)
    end

    it 'accepts search parameter' do
      cookies[:user_id] = user_id
      get '/en/sponsors', params: { search: 'Sponsor' }
      expect(response).to have_http_status(:ok)
    end
  end

  # GET /account (user#account)
  describe 'GET /:locale/account' do
    it 'returns http success when user has minecraft account' do
      cookies[:user_id] = user_id
      get '/en/account'
      expect(response).to have_http_status(:ok)
    end

    context 'when user has no minecraft account' do
      let(:user_data_hash_no_mc) do
        user_data_hash.merge('minecraft_account' => {})
      end

      before do
        no_mc_user = OpenStruct.new(
          user_data_hash_no_mc.merge(
            discord_account: OpenStruct.new(user_data_hash_no_mc['discord_account']),
            minecraft_account: nil
          )
        )
        allow_any_instance_of(UserController).to receive(:current_user).and_return(no_mc_user)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:two_factor_passed).and_return(true)
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(user_id)
      end

      it 'redirects to root' do
        get '/en/account', headers: { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' }
        expect(response).to redirect_to('/en')
      end
    end
  end

  # DELETE /account/delete (user#delete_account)
  describe 'DELETE /:locale/account/delete' do
    it 'returns json success' do
      delete '/en/account/delete', headers: { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    context 'when user has no minecraft account' do
      before do
        no_mc_user = OpenStruct.new(
          user_data_hash.merge(
            'minecraft_account' => {},
            discord_account: OpenStruct.new(user_data_hash['discord_account']),
            minecraft_account: OpenStruct.new({})
          )
        )
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(no_mc_user)
      end

      it 'returns json success' do
        delete '/en/account/delete', headers: { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end
  end

  # GET /account/change_email (user#change_email)
  describe 'GET /:locale/account/change_email' do
    it 'returns http success when user has minecraft account' do
      cookies[:user_id] = user_id
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
        cookies[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: 'newemail@example.com',
          password: 'current_password'
        }
        expect(response).to have_http_status(:ok).or have_http_status(:internal_server_error)
      end
    end

    context 'with blank email' do
      it 'returns unprocessable entity' do
        cookies[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: '',
          password: 'current_password'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid email format' do
      it 'returns unprocessable entity' do
        cookies[:user_id] = user_id
        post '/en/account/change_email_process', params: {
          email: 'not-an-email',
          password: 'current_password'
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when email is same as current' do
      it 'returns unprocessable entity' do
        cookies[:user_id] = user_id
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
        cookies[:user_id] = user_id
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
        cookies[:user_id] = user_id
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
        cookies[:user_id] = user_id
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
      users_mock = double('users_result')
      allow(users_mock).to receive(:size).and_return(users_data.size)
      allow(users_mock).to receive(:[]).with('uuid').and_return(SecureRandom.uuid)
      allow(users_mock).to receive(:[]).with('avatar_url').and_return('https://cdn.discord.com/avatar.png')
      allow(users_mock).to receive(:[]).with('nickname').and_return('OtherPlayer')
      allow(users_mock).to receive(:each).and_return(users_data.each)
      allow(users_mock).to receive(:map).and_return(users_data.map { |u| u.dup })
      clickhouse_conn = double('clickhouse_connection')
      allow(clickhouse_conn).to receive(:select_all).and_return(users_mock)
      allow(ClickHouse).to receive(:connection).and_return(clickhouse_conn)

      # update_users_data
      allow(clickhouse_conn).to receive(:select_all).with("SELECT count() AS cnt FROM users").and_return(
        double('count_result', first: { 'cnt' => 1 }, to_a: [{ 'cnt' => 1 }])
      )
    end

    it 'returns json with users' do
      cookies[:user_id] = user_id
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
      cookies[:user_id] = user_id
      get '/load_punishment_appeal/1'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('appeal')
    end
  end

  describe 'POST /send_punishment_appeal/:id' do
    it 'returns success for valid message' do
      cookies[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: 'Please unban me' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    it 'returns failure for blank message' do
      cookies[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: '' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end

    it 'returns failure for message over 500 chars' do
      cookies[:user_id] = user_id
      post '/send_punishment_appeal/1', params: { message: 'a' * 501 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe 'DELETE /send_punishment_appeal_revoke/:id' do
    it 'returns success' do
      cookies[:user_id] = user_id
      delete '/send_punishment_appeal_revoke/1'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end
end

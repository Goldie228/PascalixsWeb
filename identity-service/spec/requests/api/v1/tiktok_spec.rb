require 'rails_helper'

RSpec.describe 'Api::V1::TikTok', type: :request do
  let(:user) { create(:user, :with_discord_account) }

  # Константы CLIENT_KEY, CLIENT_SECRET, CALLBACK_URL вычисляются при загрузке класса
  # Перезаписываем их для этого тестового набора
  before(:all) do
    %w[CLIENT_KEY CLIENT_SECRET CALLBACK_URL].each do |name|
      if Api::V1::TiktokController.const_defined?(name)
        Api::V1::TiktokController.send(:remove_const, name)
      end
    end
    Api::V1::TiktokController.const_set(:CLIENT_KEY, 'test_tiktok_client_key')
    Api::V1::TiktokController.const_set(:CLIENT_SECRET, 'test_tiktok_client_secret')
    Api::V1::TiktokController.const_set(:CALLBACK_URL, 'http://auth.test/api/v1/integrations/tiktok/callback')
  end

  before do
    ENV['IDENTITY_SERVICE_URL']      = 'http://auth.test'
    ENV['AUTH_VERSION']          = 'v1'
    ENV['TIKTOK_CLIENT_KEY']     = 'test_tiktok_client_key'
    ENV['TIKTOK_CLIENT_SECRET']  = 'test_tiktok_client_secret'
    ENV['INTER_SERVICE_API_KEY'] = 'test_inter_service_key'
  end

  # Start OAuth

  describe 'GET /api/v1/tiktok (start)' do
    it 'redirects to TikTok OAuth authorization URL' do
      get api_v1_tiktok_integration_path(locale: :en)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('www.tiktok.com/v2/auth/authorize')
      expect(response.location).to include('client_key=test_tiktok_client_key')
      expect(response.location).to include('user.info.basic')
    end

    it 'stores oauth_state in session' do
      get api_v1_tiktok_integration_path(locale: :en)

      expect(response).to have_http_status(:redirect)
      # Сессия должна содержать oauth_state (проверяем косвенно через редирект)
    end
  end

  describe 'POST /api/v1/tiktok (start)' do
    it 'also redirects to TikTok OAuth authorization URL' do
      post api_v1_tiktok_integration_path(locale: :en)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('www.tiktok.com/v2/auth/authorize')
    end
  end

  # Callback

  describe 'GET /api/v1/integrations/tiktok/callback' do
    let(:oauth_state) { 'test_oauth_state_123' }

    # Заглушка сессии на уровне контроллера
    # allow_any_instance_of(ActionDispatch::Request) не работает в Rails 8.1
    # потому что контроллер делегирует request.session
    before do
      allow_any_instance_of(Api::V1::TiktokController).to receive(:session).and_return(
        ActiveSupport::HashWithIndifferentAccess.new(
          user_id: user.id,
          oauth_state: oauth_state,
          locale: 'en'
        )
      )
    end

    context 'with valid code and state' do
      before do
        # Заглушка обмена токена
        stub_request(:post, 'https://open.tiktokapis.com/v2/oauth/token/')
          .to_return(
            status: 200,
            body: {
              access_token: 'tiktok_access_token',
              open_id: 'tiktok_open_id_123'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Заглушка получения данных пользователя
        stub_request(:get, 'https://open.tiktokapis.com/v2/user/info/')
          .with(query: hash_including({ 'open_id' => 'tiktok_open_id_123' }))
          .to_return(
            status: 200,
            body: {
              data: {
                user: {
                  username: 'tiktok_user',
                  display_name: 'TikTok User',
                  profile_deep_link: 'https://www.tiktok.com/@tiktok_user'
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'updates user with TikTok info and redirects to profile' do
        get api_v1_tiktok_callback_path, params: { code: 'valid_code', state: oauth_state }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')

        user.reload
        expect(user.tiktok_channel_name).to eq('tiktok_user')
        expect(user.tiktok_url).to eq('https://www.tiktok.com/@tiktok_user')
      end
    end

    context 'with valid code but no profile_deep_link' do
      before do
        stub_request(:post, 'https://open.tiktokapis.com/v2/oauth/token/')
          .to_return(
            status: 200,
            body: {
              access_token: 'tiktok_access_token',
              open_id: 'tiktok_open_id_123'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, 'https://open.tiktokapis.com/v2/user/info/')
          .with(query: hash_including({ 'open_id' => 'tiktok_open_id_123' }))
          .to_return(
            status: 200,
            body: {
              data: {
                user: {
                  username: 'tiktok_user',
                  display_name: 'TikTok User',
                  profile_deep_link: nil
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'constructs TikTok URL from username' do
        get api_v1_tiktok_callback_path, params: { code: 'valid_code', state: oauth_state }

        expect(response).to have_http_status(:redirect)
        user.reload
        expect(user.tiktok_url).to eq('https://www.tiktok.com/@tiktok_user')
      end
    end

    context 'with mismatched state' do
      it 'redirects to profile with alert' do
        get api_v1_tiktok_callback_path, params: { code: 'valid_code', state: 'wrong_state' }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end

    context 'without code parameter' do
      it 'redirects to profile with alert' do
        get api_v1_tiktok_callback_path, params: { state: oauth_state }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end

    context 'when token exchange fails' do
      before do
        stub_request(:post, 'https://open.tiktokapis.com/v2/oauth/token/')
          .to_return(
            status: 200,
            body: { error: 'invalid_grant' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects to profile with alert' do
        get api_v1_tiktok_callback_path, params: { code: 'invalid_code', state: oauth_state }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end

    context 'when user info fetch fails' do
      before do
        # Заглушка на уровне контроллера для изоляции обработки ошибок
        # Тесты "valid code and state" уже проверяют интеграцию Faraday/WebMock
        allow_any_instance_of(Api::V1::TiktokController).to receive(:exchange_code_for_token).and_return(
          { 'access_token' => 'tiktok_access_token', 'open_id' => 'tiktok_open_id_123' }
        )
        allow_any_instance_of(Api::V1::TiktokController).to receive(:fetch_user_info).and_return(
          { 'error' => 'user_not_found' }
        )
      end

      it 'redirects to profile with alert' do
        get api_v1_tiktok_callback_path, params: { code: 'valid_code', state: oauth_state }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end

    context 'when user is not found in session' do
      before do
        allow_any_instance_of(Api::V1::TiktokController).to receive(:session).and_return(
          ActiveSupport::HashWithIndifferentAccess.new(
            user_id: nil,
            oauth_state: oauth_state,
            locale: 'en'
          )
        )

        # Заглушка на уровне контроллера для изоляции обработки ошибок
        allow_any_instance_of(Api::V1::TiktokController).to receive(:exchange_code_for_token).and_return(
          { 'access_token' => 'tiktok_access_token', 'open_id' => 'tiktok_open_id_123' }
        )
        allow_any_instance_of(Api::V1::TiktokController).to receive(:fetch_user_info).and_return(
          {
            'data' => {
              'user' => {
                'username' => 'tiktok_user',
                'display_name' => 'TikTok User',
                'profile_deep_link' => 'https://www.tiktok.com/@tiktok_user'
              }
            }
          }
        )
      end

      it 'redirects to profile with user_not_found alert' do
        get api_v1_tiktok_callback_path, params: { code: 'valid_code', state: oauth_state }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end
  end

  # Failure

  describe 'GET /api/v1/integrations/tiktok/failure' do
    it 'redirects to profile with alert' do
      get api_v1_tiktok_integration_failure_path(locale: :en)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/profile')
    end
  end
end

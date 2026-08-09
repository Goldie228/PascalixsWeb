require 'rails_helper'

RSpec.describe 'Api::V1::Integrations', type: :request do
  # Переменные окружения до загрузки Rails
  before(:all) do
    ENV['AUTH_SERVICE_URL'] = 'http://auth.test'
    ENV['AUTH_VERSION'] = 'v1'
    ENV['GOOGLE_CLIENT_ID'] = 'test_google_client_id'
    ENV['TWITCH_CLIENT_ID'] = 'test_twitch_client_id'
    ENV['TWITCH_CLIENT_SECRET'] = 'test_twitch_client_secret'
    ENV['INTER_SERVICE_API_KEY'] = 'test_inter_service_key'
  end

  # YouTube OAuth

  describe 'GET /api/v1/integrations/youtube' do
    it 'redirects to Google OAuth authorization URL' do
      get '/en/api/v1/integrations/youtube'

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('accounts.google.com/o/oauth2/auth')
      expect(response.location).to include('client_id=test_google_client_id')
    end
  end

  describe 'GET /api/v1/integrations/youtube/callback' do
    context 'without omniauth data' do
      it 'redirects to failure path' do
        get '/api/v1/integrations/youtube/callback'

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('failure')
      end
    end
  end

  describe 'GET /api/v1/integrations/youtube/failure' do
    it 'redirects to profile with alert' do
      get '/en/api/v1/integrations/youtube/failure'

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/profile')
    end
  end

  # Twitch OAuth

  describe 'GET /api/v1/integrations/twitch' do
    it 'redirects to Twitch OAuth authorization URL' do
      get '/en/api/v1/integrations/twitch'

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('id.twitch.tv/oauth2/authorize')
      expect(response.location).to include('client_id=test_twitch_client_id')
    end
  end

  describe 'GET /api/v1/integrations/twitch/callback' do
    context 'without code parameter' do
      it 'returns parameter missing error' do
        get '/api/v1/integrations/twitch/callback'

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with invalid code' do
      before do
        stub_request(:post, 'https://id.twitch.tv/oauth2/token')
          .to_return(
            status: 200,
            body: { error: 'invalid_grant' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects to failure path' do
        get '/api/v1/integrations/twitch/callback', params: { code: 'invalid_code' }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/profile')
      end
    end
  end

  describe 'GET /api/v1/integrations/twitch/failure' do
    it 'redirects to profile with alert' do
      get '/en/api/v1/integrations/twitch/failure'

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/profile')
    end
  end
end

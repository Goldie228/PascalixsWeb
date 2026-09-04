require 'rails_helper'

RSpec.describe Api::V1::CallbacksController, type: :request do
  let(:api_key) { 'test-inter-service-key' }

  before do
    ENV['INTER_SERVICE_API_KEY'] = api_key
  end
  let(:valid_user_data) do
    {
      id: 'user-123',
      email: 'player@example.com',
      username: 'TestPlayer',
      is_registered: true
    }
  end

  describe 'POST /api/v1/callbacks/auth_event' do
    context 'with valid API key' do
      it 'returns success with valid user data' do
        post '/api/v1/callbacks/auth_event',
          params: { user: valid_user_data }.to_json,
          headers: { 'X-API-KEY' => api_key, 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('success')
      end

      it 'returns success with minimal user data' do
        post '/api/v1/callbacks/auth_event',
          params: { user: { id: '1', is_registered: false } }.to_json,
          headers: { 'X-API-KEY' => api_key, 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('success')
      end

      it 'permits only allowed user fields' do
        post '/api/v1/callbacks/auth_event',
          params: {
            user: {
              id: '1',
              email: 'test@example.com',
              username: 'TestUser',
              is_registered: true,
              secret_field: 'should_be_ignored'
            }
          }.to_json,
          headers: { 'X-API-KEY' => api_key, 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without API key' do
      it 'returns unauthorized' do
        post '/api/v1/callbacks/auth_event',
          params: { user: valid_user_data }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end
    end

    context 'with invalid API key' do
      it 'returns unauthorized' do
        post '/api/v1/callbacks/auth_event',
          params: { user: valid_user_data }.to_json,
          headers: { 'X-API-KEY' => 'wrong-key', 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end
    end

    context 'with missing user param' do
      it 'returns unprocessable entity' do
        post '/api/v1/callbacks/auth_event',
          params: { other: 'data' }.to_json,
          headers: { 'X-API-KEY' => api_key, 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe 'Api::V1::Player', type: :request do
  let(:api_key) { ENV.fetch('INTER_SERVICE_API_KEY', 'test-api-key') }
  let(:headers) { { 'Authorization' => "Bearer #{api_key}" } }
  let(:nickname) { 'TestPlayer' }
  let(:password_hash) { '$2a$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234' }

  describe 'GET /api/v1/players/:nickname/check_password' do
    context 'when authentication is missing' do
      it 'returns 401 unauthorized' do
        get "/api/v1/players/#{nickname}/check_password", params: { password: 'test' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('unauthorized')
      end
    end

    context 'when authentication is invalid' do
      it 'returns 401 unauthorized' do
        get "/api/v1/players/#{nickname}/check_password",
            params: { password: 'test' },
            headers: { 'Authorization' => 'Bearer wrong-key' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('unauthorized')
      end
    end

    context 'with valid authentication' do
      context 'when password parameter is missing' do
        it 'returns 400 bad request' do
          get "/api/v1/players/#{nickname}/check_password", headers: headers

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('missing_parameters')
        end
      end

      context 'when password parameter is blank' do
        it 'returns 400 bad request' do
          get "/api/v1/players/#{nickname}/check_password",
              params: { password: '   ' },
              headers: headers

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('missing_parameters')
        end
      end

      context 'when player does not exist' do
        it 'returns 404 not found' do
          get "/api/v1/players/NonExistentPlayer/check_password",
              params: { password: 'somepassword' },
              headers: headers

          expect(response).to have_http_status(:not_found)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('not_found')
        end
      end

      context 'when player exists' do
        let!(:authme) { create(:authme, realname: nickname, password: password_hash) }

        context 'with correct password' do
          it 'returns 200 ok' do
            get "/api/v1/players/#{nickname}/check_password",
                params: { password: password_hash },
                headers: headers

            expect(response).to have_http_status(:ok)
            body = JSON.parse(response.body)
            expect(body['status']).to eq('ok')
            expect(body['message']).to include('совпадает')
          end
        end

        context 'with incorrect password' do
          it 'returns 401 unauthorized' do
            get "/api/v1/players/#{nickname}/check_password",
                params: { password: 'wrong_password_hash' },
                headers: headers

            expect(response).to have_http_status(:unauthorized)
            body = JSON.parse(response.body)
            expect(body['error']).to eq('invalid_password')
            expect(body['message']).to include('неверен')
          end
        end

        context 'with whitespace-only nickname in URL' do
          it 'returns 400 bad request due to blank nickname after strip' do
            get "/api/v1/players/%20%20%20/check_password",
                params: { password: password_hash },
                headers: headers

            expect(response).to have_http_status(:bad_request)
            body = JSON.parse(response.body)
            expect(body['error']).to eq('missing_parameters')
          end
        end
      end
    end
  end
end

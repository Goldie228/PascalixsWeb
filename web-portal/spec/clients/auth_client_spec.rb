require 'rails_helper'

RSpec.describe AuthClient, type: :client do
  let(:base_url) { 'http://auth-service.test' }

  before do
    # Убеждаемся что base_uri задан для тестов
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('IDENTITY_SERVICE_URL').and_return(base_url)

    # Применяем base_uri заново — HTTParty читает его при загрузке класса
    described_class.base_uri(base_url)
  end

  after do
    # Сбрасываем base_uri чтобы не утекло в другие тесты
    described_class.base_uri(nil)
  end

  describe '.get_user' do
    let(:fields) { %w[email username] }

    context 'when user_id is :current' do
      it 'calls GET /api/v1/me/fields with comma-separated fields' do
        stub = stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email,username' })
          .to_return(
            status: 200,
            body: { email: 'me@test.com', username: 'me' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(:current, fields)

        expect(stub).to have_been_requested.once
        expect(response.parsed_response).to eq({ 'email' => 'me@test.com', 'username' => 'me' })
      end

      it 'returns the HTTParty response with correct status' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email,username' })
          .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

        response = described_class.get_user(:current, fields)

        expect(response.code).to eq(200)
      end
    end

    context 'when user_id is a specific id' do
      let(:user_id) { 'abc-123-def' }

      it 'calls GET /api/v1/users/:user_id/fields with comma-separated fields' do
        stub = stub_request(:get, "#{base_url}/api/v1/users/#{user_id}/fields")
          .with(query: { fields: 'email,username' })
          .to_return(
            status: 200,
            body: { email: 'user@test.com', username: 'user' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(user_id, fields)

        expect(stub).to have_been_requested.once
        expect(response.parsed_response).to eq({ 'email' => 'user@test.com', 'username' => 'user' })
      end

      it 'handles a single field in the array' do
        stub = stub_request(:get, "#{base_url}/api/v1/users/#{user_id}/fields")
          .with(query: { fields: 'email' })
          .to_return(
            status: 200,
            body: { email: 'solo@test.com' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(user_id, %w[email])

        expect(stub).to have_been_requested.once
        expect(response.parsed_response).to eq({ 'email' => 'solo@test.com' })
      end
    end

    context 'when the request succeeds' do
      it 'returns parsed JSON response for 200 OK' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(
            status: 200,
            body: { email: 'ok@test.com' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(200)
        expect(response.parsed_response['email']).to eq('ok@test.com')
      end
    end

    context 'when the auth service returns a 4xx error' do
      it 'returns the response for 404 Not Found (HTTParty does not raise on 4xx)' do
        stub_request(:get, "#{base_url}/api/v1/users/nonexistent/fields")
          .with(query: { fields: 'email' })
          .to_return(
            status: 404,
            body: '{"error":"not found"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user('nonexistent', %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(404)
        expect(response.parsed_response).to eq({ 'error' => 'not found' })
      end

      it 'returns the response for 401 Unauthorized' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(status: 401, body: '{"error":"unauthorized"}')

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(401)
      end

      it 'returns the response for 422 Unprocessable Entity' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(status: 422, body: '{"error":"invalid fields"}')

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(422)
      end
    end

    context 'when the auth service returns a 5xx error' do
      it 'returns the response for 500 Internal Server Error (HTTParty does not raise on 5xx)' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(
            status: 500,
            body: '{"error":"internal error"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(500)
        expect(response.parsed_response).to eq({ 'error' => 'internal error' })
      end

      it 'returns the response for 503 Service Unavailable' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(status: 503, body: '{"error":"service unavailable"}')

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_a(HTTParty::Response)
        expect(response.code).to eq(503)
      end
    end

    context 'when a timeout occurs' do
      it 'returns nil and logs the error' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_timeout

        expect(Rails.logger).to receive(:error).with(/AuthClient Error/)

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_nil
      end
    end

    context 'when the connection is refused' do
      it 'returns nil and logs the error' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_raise(Errno::ECONNREFUSED)

        expect(Rails.logger).to receive(:error).with(/AuthClient Error/)

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_nil
      end
    end

    context 'when a generic network error occurs' do
      it 'returns nil and logs the error for SocketError' do
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_raise(SocketError.new('getaddrinfo: Name or service not known'))

        expect(Rails.logger).to receive(:error).with(/AuthClient Error/)

        response = described_class.get_user(:current, %w[email])

        expect(response).to be_nil
      end
    end

    context 'circuit breaker behavior' do
      it 'does not implement a circuit breaker (rescues all StandardError uniformly)' do
        # AuthClient ловит StandardError и возвращает nil для всех ошибок.
        # Паттерна circuit breaker нет — каждый вызов независим
        # пытается выполнить HTTP-запрос и обрабатывает ошибку одинаково.
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_raise(Errno::ECONNREFUSED)

        # Первый вызов возвращает nil
        expect(described_class.get_user(:current, %w[email])).to be_nil

        # Второй вызов всё ещё пытается (circuit breaker не открыт)
        stub_request(:get, "#{base_url}/api/v1/me/fields")
          .with(query: { fields: 'email' })
          .to_return(
            status: 200,
            body: { email: 'recovered@test.com' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = described_class.get_user(:current, %w[email])
        expect(response).not_to be_nil
        expect(response.parsed_response['email']).to eq('recovered@test.com')
      end
    end
  end
end

require 'rails_helper'

RSpec.describe 'Purchases', type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:nickname) { 'TestPlayer' }
  let(:auth_service_url) { 'http://auth-service.test' }
  let(:inter_service_key) { 'test-key' }

  # Мок данных пользователя (Redis/API)
  let(:user_data_hash) do
    {
      'id' => user_id,
      'user_id' => user_id,
      'nickname' => nickname,
      'is_added' => true,
      'about_me' => 'Hello',
      'role_name' => 'PLAYER',
      'role_color' => '#FFFFFF',
      'is_sponsor' => false,
      'discord_account' => {
        'id' => 1, 'user_id' => user_id, 'discord_id' => '123456789',
        'username' => 'testuser', 'discriminator' => '0001',
        'email' => 'test@example.com', 'avatar' => 'avatar_hash'
      },
      'minecraft_account' => {
        'id' => 1, 'user_id' => user_id, 'nickname' => nickname,
        'password_hash' => 'hashed'
      }
    }
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

  # Заглушка Kafka-продюсера
  def stub_kafka
    producer = instance_double('KarafkaProducer')
    allow(producer).to receive(:produce_async).and_return(true)
    allow(Karafka).to receive(:producer).and_return(producer)
  end

  # Заглушка Redis для загрузки данных
  def stub_redis_for_user
    allow(REDIS_CLIENT).to receive(:hgetall).with("user_updates:#{user_id}").and_return(
      { Time.now.to_i.to_s => user_data_hash.to_json }
    )
    allow(REDIS_CLIENT).to receive(:hgetall).with(anything).and_return({})
    allow(REDIS_CLIENT).to receive(:get).and_return(nil)
    allow(REDIS_CLIENT).to receive(:set).and_return(true)
    allow(REDIS_CLIENT).to receive(:del).and_return(true)
    allow(REDIS_CLIENT).to receive(:hget).and_return(nil)
    allow(REDIS_CLIENT).to receive(:hset).and_return(true)
  end

  def mock_httparty_response(body:, status: 200)
    parsed = begin
      JSON.parse(body)
    rescue
      body
    end
    double('HTTParty::Response', body: body, success?: status.between?(200, 299), code: status, status_code: status, parsed_response: parsed)
  end

  before do
    ENV['AUTH_SERVICE_URL'] = auth_service_url
    ENV['INTER_SERVICE_API_KEY'] = inter_service_key
    stub_clickhouse
    stub_kafka
    stub_redis_for_user
    stub_current_user
    cookies[:user_id] = user_id
  end

  # GET /purchases (purchases#index)
  describe 'GET /:locale/purchases' do
    context 'when auth service returns purchases' do
      let(:purchases_response) do
        [
          {
            'id' => 1,
            'purchase_type' => 'pass_buy',
            'amount' => '10.00',
            'currency' => 'USD',
            'status' => 'completed',
            'purchaser_user_id' => user_id,
            'created_at' => '2026-01-01T00:00:00Z'
          }
        ].to_json
      end

      before do
        allow(HTTParty).to receive(:get).and_return(mock_httparty_response(body: purchases_response))
      end

      it 'returns http success' do
        get '/en/purchases'
        expect(response).to have_http_status(:ok)
      end

      it 'returns purchases as json' do
        get '/en/purchases'
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.first['purchase_type']).to eq('pass_buy')
      end
    end

    context 'with status filter' do
      before do
        allow(HTTParty).to receive(:get).and_return(mock_httparty_response(body: '[]'))
      end

      it 'passes status filter to auth service' do
        get '/en/purchases', params: { status: 'completed' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with purchase_type filter' do
      before do
        allow(HTTParty).to receive(:get).and_return(mock_httparty_response(body: '[]'))
      end

      it 'passes purchase_type filter to auth service' do
        get '/en/purchases', params: { purchase_type: 'pass_buy' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when auth service fails' do
      before do
        allow(HTTParty).to receive(:get).and_return(mock_httparty_response(body: '{"error": "internal error"}', status: 500))
      end

      it 'returns internal server error' do
        get '/en/purchases'
        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_an(Array)
      end
    end
  end

  # POST /purchases (purchases#create)
  describe 'POST /:locale/purchases' do
    context 'with valid params' do
      before do
        allow(HTTParty).to receive(:post).and_return(mock_httparty_response(body: '{"id": 1, "status": "pending"}', status: 201))
      end

      it 'creates a purchase and returns created status' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: '10.00',
            currency: 'USD',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(1)
      end
    end

    context 'with amount including currency suffix' do
      before do
        allow(HTTParty).to receive(:post).and_return(mock_httparty_response(body: '{"id": 2, "status": "pending"}', status: 201))
      end

      it 'parses amount and currency from combined string' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: '25.50EUR',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'with missing required params' do
      it 'returns unprocessable entity for missing purchase_type' do
        post '/en/purchases', params: {
          purchase: {
            amount: '10.00',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_an(Array)
      end

      it 'returns unprocessable entity for missing amount' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with negative amount' do
      it 'returns unprocessable entity' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: '-5.00',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(match(/положительной/))
      end
    end

    context 'with zero amount' do
      it 'returns unprocessable entity' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: '0',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid amount format' do
      it 'returns unprocessable entity' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: 'abc',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with pass_gift type but no target_user_id' do
      it 'returns unprocessable entity' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_gift',
            amount: '10.00',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join).to include('target_user_id')
      end
    end

    context 'with pass_gift type and target_user_id' do
      before do
        allow(HTTParty).to receive(:post).and_return(mock_httparty_response(body: '{"id": 3, "status": "pending"}', status: 201))
      end

      it 'creates a gift purchase' do
        target_id = SecureRandom.uuid
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_gift',
            amount: '10.00',
            purchaser_user_id: user_id,
            target_user_id: target_id
          }
        }, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'when auth service returns error' do
      before do
        allow(HTTParty).to receive(:post).and_return(mock_httparty_response(body: '{"errors": ["Invalid data"]}', status: 422))
      end

      it 'returns unprocessable entity with errors' do
        post '/en/purchases', params: {
          purchase: {
            purchase_type: 'pass_buy',
            amount: '10.00',
            purchaser_user_id: user_id
          }
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Invalid data')
      end
    end

    context 'without purchase wrapper params' do
      it 'returns unprocessable entity for parameter missing' do
        post '/en/purchases', params: {}, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # PATCH /purchases/:id (purchases#update)
  describe 'PATCH /:locale/purchases/:id' do
    let(:purchase_id) { 1 }

    context 'with valid params' do
      before do
        allow(HTTParty).to receive(:patch).and_return(mock_httparty_response(body: '{"id": 1, "status": "approved"}'))
      end

      it 'updates the purchase and returns success' do
        patch "/en/purchases/#{purchase_id}", params: {
          status: 'approved'
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('approved')
      end
    end

    context 'with amount update' do
      before do
        allow(HTTParty).to receive(:patch).and_return(mock_httparty_response(body: '{"id": 1, "amount": "20.00"}'))
      end

      it 'updates the amount' do
        patch "/en/purchases/#{purchase_id}", params: {
          amount: '20.00'
        }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when auth service returns error' do
      before do
        allow(HTTParty).to receive(:patch).and_return(mock_httparty_response(body: '{"errors": ["Cannot update"]}', status: 422))
      end

      it 'returns unprocessable entity' do
        patch "/en/purchases/#{purchase_id}", params: {
          status: 'invalid_status'
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Cannot update')
      end
    end
  end

  # DELETE /purchases/:id (purchases#destroy)
  describe 'DELETE /:locale/purchases/:id' do
    let(:purchase_id) { 1 }

    context 'when deletion succeeds' do
      before do
        allow(HTTParty).to receive(:delete).and_return(double('HTTParty::Response', body: '', success?: true, status_code: 204, parsed_response: nil))
      end

      it 'returns no content' do
        delete "/en/purchases/#{purchase_id}"
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when auth service returns error' do
      before do
        allow(HTTParty).to receive(:delete).and_return(mock_httparty_response(body: '{"errors": ["Cannot delete"]}', status: 422))
      end

      it 'returns unprocessable entity' do
        delete "/en/purchases/#{purchase_id}"
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Cannot delete')
      end
    end
  end
end

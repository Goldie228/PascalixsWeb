require 'rails_helper'

RSpec.describe 'TwoFactorAuthentications', type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:auth_service_url) { ENV.fetch('AUTH_SERVICE_URL', 'http://auth-service.test') }

  # Мок данных пользователя (Redis/API)
  let(:user_data_hash) do
    {
      'id' => user_id,
      'user_id' => user_id,
      'nickname' => 'TestPlayer',
      'is_added' => true,
      'about_me' => 'Hello',
      'role_name' => 'PLAYER',
      'role_color' => '#FFFFFF',
      'is_sponsor' => false,
      'discord_account' => {
        'id' => 1,
        'user_id' => user_id,
        'discord_id' => '123456789',
        'username' => 'testuser',
        'discriminator' => '0001',
        'email' => 'test@example.com',
        'avatar' => 'avatar_hash'
      },
      'minecraft_account' => {
        'id' => 1,
        'user_id' => user_id,
        'nickname' => 'TestPlayer',
        'password_hash' => 'hashed'
      }
    }
  end

  # Заглушка ClickHouse для update_users_data
  def stub_clickhouse
    clickhouse_result = double('clickhouse_result')
    allow(clickhouse_result).to receive(:first).and_return({ 'cnt' => 1 })
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

  # Заглушка ActiveJob классов
  def stub_jobs
    allow(TwoFactorResponseJob).to receive(:perform_async).and_return(true)
    allow(EmailResponseJob).to receive(:perform_async).and_return(true)
    allow(CodeValidityJob).to receive(:perform_async).and_return(true)
  end

  before do
    stub_clickhouse
    stub_kafka
    stub_redis_for_user
    stub_jobs
    cookies.encrypted[:user_id] = user_id
    cookies.encrypted[:two_factor_passed] = true
  end

  # GET /two_factor_authentication (two_factor_authentications#show)
  describe 'GET /:locale/two_factor_authentication' do
    it 'returns http success when user is logged in' do
      get '/en/two_factor_authentication'
      expect(response).to have_http_status(:ok)
    end

    it 'clears flash on show' do
      session[:notice] = 'test notice'
      get '/en/two_factor_authentication'
      expect(flash[:notice]).to be_nil
    end

    context 'when user is not logged in' do
      before do
        cookies.delete(:user_id)
        cookies.delete(:two_factor_passed)
      end

      it 'redirects to login' do
        get '/en/two_factor_authentication'
        expect(response).to redirect_to('/en/login')
      end
    end

    context 'when two_factor_passed is not set' do
      before do
        cookies.encrypted[:two_factor_passed] = false
      end

      it 'redirects to root' do
        get '/en/two_factor_authentication'
        expect(response).to redirect_to('/en')
      end
    end
  end

  # POST /two_factor_authentication/verify (two_factor_authentications#verify)
  describe 'POST /:locale/two_factor_authentication/verify' do
    context 'with valid 6-digit OTP' do
      it 'returns success' do
        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: '123456' }
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end

      it 'sends verify_code kafka message' do
        expect(Karafka.producer).to receive(:produce_async).with(
          kind_of(String),
          hash_including(topic: 'two_factor_requests')
        ).and_return(true)

        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: '654321' }
        }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with blank OTP' do
      it 'returns failure with empty_code error' do
        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: '' }
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to be_present
      end
    end

    context 'with invalid OTP format (not 6 digits)' do
      it 'returns failure for short code' do
        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: '12345' }
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to be_present
      end

      it 'returns failure for non-numeric code' do
        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: 'abcdef' }
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to be_present
      end

      it 'returns failure for code too long' do
        post '/en/two_factor_authentication/verify', params: {
          two_factor_authentication: { otp_attempt: '1234567' }
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to be_present
      end
    end
  end

  # POST /two_factor_authentication/resend_code (two_factor_authentications#resend_code)
  describe 'POST /:locale/two_factor_authentication/resend_code' do
    it 'sets notice and redirects to two_factor_authentication page' do
      post '/en/two_factor_authentication/resend_code'
      expect(response).to redirect_to('/en/two_factor_authentication')
      expect(flash[:notice]).to be_present
    end
  end

  # POST /two_factor_success (two_factor_authentications#success_update)
  describe 'POST /:locale/two_factor_success' do
    it 'returns success and sets two_factor_passed in session' do
      post '/en/two_factor_success', as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    it 'sets session two_factor_passed to true' do
      post '/en/two_factor_success'
      expect(session[:two_factor_passed]).to be true
    end
  end
end

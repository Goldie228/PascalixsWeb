class SessionsController < ApplicationController
  skip_after_action :drop_session_flash, only: :destroy

  def new
    redirect_to localized_root_path if current_user
  end

  def create
    correlation_id = SecureRandom.uuid

    produce_with_retries(
      "user_login_events",
      {
        correlation_id: correlation_id,
        nickname: params[:nickname],
        password: params[:password]
      }.to_json
    )

    response = wait_for_response(correlation_id)

    if response['status'] == 'auth'
      session[:user_id] = response['user_id']
      render json: { redirect_url: user_two_factor_authentication_path }, status: :ok
    else
      render json: { error: t('sessions.login_failure') }, status: :unauthorized
    end
  end

  def destroy
    # Выход пользователя
    session[:user_id] = nil
    session[:is_registered] = nil
    session[:two_factor_authenticated] = nil
    
    # Публикуем событие в Kafka
    if current_user
      begin
        produce_with_retries(
          "user_logout_events",
          { user_id: current_user.id, timestamp: Time.current.to_i }.to_json
        )
      rescue => e
        Rails.logger.error "Failed to publish logout event: #{e.message}"
      end
    end
    
    session[:notice] = t('sessions.logout_success')
    redirect_to localized_root_path
  end

  private

  def wait_for_response(correlation_id, timeout: 5)
    start_time = Time.now

    loop do
      response = fetch_response(correlation_id)

      return response if response

      if Time.now - start_time > timeout
        Rails.logger.error "Timeout waiting for response for correlation ID: #{correlation_id}"
        return { 'status' => 'not auth', 'user_id' => nil }
      end
      
      sleep(0.5)
    end
  end

  def fetch_response(correlation_id, redis_client: Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')))
    response = redis_client.get("auth_responses:#{correlation_id}")
    
    Rails.logger.info "Fetched response from Redis for correlation ID: #{correlation_id}, Response: #{response.inspect}"

    if response.nil?
      Rails.logger.warn "No response found in Redis for correlation ID: #{correlation_id}"
      return nil
    end

    begin
      JSON.parse(response)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON for correlation ID: #{correlation_id}, Error: #{e.message}"
      return nil
    end
  end
end
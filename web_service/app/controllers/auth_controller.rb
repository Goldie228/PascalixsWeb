class AuthController < ApplicationController
  def login
    if @current_user
      redirect_to localized_root_path
    end
  end

  def logout(redis_client: Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")))
    redis_client.del("user_updates::#{session[:user_id]}") if session[:user_id]
    session[:user_id] = nil
    session[:two_factor_passed] = nil
    session[:notice] = t("sessions.logout_success")
  end

  def discord
  end

  def register_minecraft
    if current_user.nil?
      redirect_to localized_root_path
      return
    end
    @minecraft_account = current_user.build_minecraft_account
  end

  def submit_registration
    return redirect_to(localized_root_path) if current_user.nil?

    correlation_id = SecureRandom.uuid
    produce_with_retries(
      "minecraft_registration_requests",
      payload: {
        user_id: current_user.id,
        locale: I18n.locale,
        **minecraft_params
      }.merge(correlation_id: correlation_id)
    )

    response = wait_for_response(correlation_id)

    respond_to do |format|
      if response["status"] == "error"
        formatted_errors = response["errors"].each_with_object({}) do |(field, messages), hash|
          hash[field] = messages
        end

        format.json { render json: { status: "error", errors: formatted_errors }, status: :unprocessable_entity }
        format.html { render :register_minecraft, locals: { errors: formatted_errors } }
      else
        format.json { render json: { status: "success", redirect_to: localized_root_path } }
        format.html { redirect_to localized_root_path }
      end
    end
  end

  def handle_registration_response(response)
    if response["status"] == "error"
      render json: { status: "error", errors: response["errors"] }, status: :unprocessable_entity
    else
      redirect_to localized_root_path
    end
  end

  def wait_for_response(correlation_id, timeout: 5)
    start_time = Time.now

    loop do
      response = fetch_response(correlation_id)

      return response if response

      if Time.now - start_time > timeout
        Rails.logger.error "Timeout waiting for response for correlation ID: #{correlation_id}"
        return { "status" => "error", "errors" => [] }
      end

      sleep(0.1)
    end
  end

  private

  def minecraft_params
    params.require(:minecraft_account).permit(:nickname, :password, :password_confirmation)
  end

  def fetch_response(correlation_id, redis_client: Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")))
    response = redis_client.get("registration_responses:#{correlation_id}")
    Rails.logger.info "Fetched response from Redis for correlation ID: #{correlation_id}, Response: #{response.inspect}"

    if response.nil?
      Rails.logger.warn "No response found in Redis for correlation ID: #{correlation_id}"
      return nil
    end

    begin
      JSON.parse(response)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON for correlation ID: #{correlation_id}, Error: #{e.message}"
    end
  end
end

class PagesController < ApplicationController
  def home
  end

  def goodbye
    redirect_to localized_root_path and return unless cookies[:goodbye]

    cookies.delete(:goodbye)
  end

  def pending_email_verification
    unless session[:send_email]
      redirect_to localized_root_path and return
    end

    @new_email = session[:new_email]

    session.delete(:send_email)
    session.delete(:new_email)
  end

  def change_email_confirm
    token = params[:token].to_s.strip

    @success = false
    @new_email = ""

    return unless current_user.present?
    return if token.blank?

    raw = REDIS_CLIENT.get("token:#{token}")
    return if raw.blank?

    begin
      payload = JSON.parse(raw)

      redis_user_id = payload["user_id"]
      new_email = payload["new_email"]

      if redis_user_id == current_user.id && new_email.present?
        @success = true
        @new_email = new_email

        payload = {
          user_id: current_user.id,
          email: new_email,
        }

        produce_with_retries("change_email", payload.to_json)
        REDIS_CLIENT.del("token:#{token}")
      end
    rescue JSON::ParserError => e
      Rails.logger.error "[EmailConfirm] Ошибка парсинга JSON: #{e.message}"
    end
  end

  def update_timezone
    time_zone = params[:time_zone]
    if time_zone.present?
      session[:time_zone] = time_zone
      redirect_back(fallback_location: root_path)
    else
      render json: { error: "Time zone not provided" }, status: :bad_request
    end
  end
end

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

  def pending_password_reset
    unless session[:password_reset_pending] && current_user
      redirect_to localized_root_path and return
    end

    token = SecureRandom.hex(32)

    payload = {
      user_id: current_user.id
    }

    REDIS_CLIENT.set("token_pass:#{token}", payload.to_json, ex: 2.hours.to_i)

    payload = {
      token: token,
      email: current_user.discord_account.email,
      nickname: current_user&.minecraft_account&.nickname || current_user&.discord_username&.username,
      locale: I18n.locale,
      time_zone: session[:time_zone] || "UTC"
    }

    produce_with_retries('notification.password_reset.sent', payload.to_json)

    session.delete(:password_reset_pending)
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
          email: new_email
        }

        produce_with_retries('identity.user.email_changed', payload.to_json)
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

  def pending_email_login
    unless session[:email_login]
      redirect_to localized_root_path and return
    end

    @email = session[:sended_email]

    session.delete(:sended_email)
    session.delete(:email_login)
  end

  def donate
    @is_banned = false
    @is_muted = false
    @is_sponsor = current_user&.is_sponsor || false

    unless current_user&.minecraft_account&.nickname.nil?
      @punishments = fetch_punishments(current_user&.minecraft_account&.nickname)
      if @punishments
        @is_banned = is_banned?(@punishments)
        @is_muted = is_muted?(@punishments)
      end
    end
  end

  def gallery
  end
end

class SendPasswordResetEmailConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        payload = JSON.parse(message.payload)
        Rails.logger.info payload

        token = payload["token"]
        email = payload["email"]
        nickname = payload["nickname"]
        locale = payload["locale"].to_s
        I18n.locale = I18n.available_locales.include?(locale.to_sym) ? locale.to_sym : I18n.default_locale
        zone = payload["time_zone"].to_s
        valid_zone = ActiveSupport::TimeZone[zone] ? zone : "UTC"

        UserMailer.reset_password(email, token, nickname, valid_zone).deliver_now

        Rails.logger.info "Message sended!"
      rescue => e
        Rails.logger.error "Error: #{e.message}"
      end
    end
  end
end

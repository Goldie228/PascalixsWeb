class UserMailer < ApplicationMailer
  default from: 'no-reply@pascalixs.com'

  def two_factor_code(email, code, otp_valid_until)
    @code = code
    @otp_valid_until = otp_valid_until

    mail(to: email, subject: t('devise.two_factor_authentication.subject'))
  end

  def check_email(email, token, nickname, time_zone)
    @token = token
    @nickname = nickname
    @time_zone = time_zone
    @confirmation_url = "#{ENV["WEB_SERVICE_URL"]}/#{I18n.locale}/confirm_email/#{@token}"

    mail(to: email, subject: t('emails.check_email.subject'))
  end
end

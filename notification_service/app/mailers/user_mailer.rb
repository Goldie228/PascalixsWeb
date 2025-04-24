class UserMailer < ApplicationMailer
  default from: 'no-reply@pascalixs.com'

  def two_factor_code(user, code, otp_valid_until, timezone)
    @user = user
    @code = code
    @otp_valid_until = otp_valid_until
    @timezone = timezone
    
    mail(to: @user.email, subject: t('user_mailer.two_factor_code.subject'))
  end
end

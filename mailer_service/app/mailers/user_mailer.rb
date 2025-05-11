class UserMailer < ApplicationMailer
  default from: 'no-reply@pascalixs.com'

  def two_factor_code(email, code, otp_valid_until)
    @code = code
    @otp_valid_until = otp_valid_until

    mail(to: email, subject: t('devise.two_factor_authentication.subject'))
  end
end

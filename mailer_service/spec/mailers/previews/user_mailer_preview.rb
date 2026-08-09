# Все письма: http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Предпросмотр письма с кодом 2FA
  def two_factor_code
    UserMailer.two_factor_code(
      'user@example.com',
      '123456',
      30.minutes.from_now.strftime('%Y-%m-%d %H:%M:%S %Z')
    )
  end

  # Предпросмотр письма подтверждения email
  def check_email
    UserMailer.check_email(
      'user@example.com',
      'abc123token456',
      'TestPlayer',
      'UTC'
    )
  end

  # Предпросмотр письма сброса пароля
  def reset_password
    UserMailer.reset_password(
      'user@example.com',
      'xyz789token012',
      'TestPlayer',
      'UTC'
    )
  end
end

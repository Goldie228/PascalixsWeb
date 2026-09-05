class UserMailer < ApplicationMailer
  def welcome
    @user = User.find_by(id: @opts[:user_id])
    return head :not_found unless @user

    mail(
      to: @user.email,
      subject: I18n.t('mailer.welcome.subject', default: 'Welcome to Pascalixs!')
    )
  end

  def password_reset
    @user = User.find_by(id: @opts[:user_id])
    return head :not_found unless @user
    @token = @opts[:token]

    mail(
      to: @user.email,
      subject: I18n.t('mailer.password_reset.subject', default: 'Password Reset')
    )
  end

  def email_changed
    @user = User.find_by(id: @opts[:user_id])
    return head :not_found unless @user
    @new_email = @opts[:new_email]

    mail(
      to: @user.email,
      subject: I18n.t('mailer.email_changed.subject', default: 'Email Changed')
    )
  end

  def punishment_issued
    @user = User.find_by(id: @opts[:user_id])
    return head :not_found unless @user
    @punishment = @opts[:punishment]

    mail(
      to: @user.email,
      subject: I18n.t('mailer.punishment_issued.subject', default: 'New Punishment')
    )
  end

  def punishment_resolved
    @user = User.find_by(id: @opts[:user_id])
    return head :not_found unless @user
    @punishment = @opts[:punishment]

    mail(
      to: @user.email,
      subject: I18n.t('mailer.punishment_resolved.subject', default: 'Punishment Resolved')
    )
  end
end

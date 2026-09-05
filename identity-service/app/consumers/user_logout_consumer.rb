class UserLogoutConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = parse_payload(message.payload)
      next unless data

      token = data['token']
      next unless token

      session = Session.find_by(token: token)
      unless session
        Rails.logger.warn "[UserLogout] No session for token: #{token}"
        next
      end

      user = session.user
      timestamp = data['timestamp']
      ip_address = data['ip_address']

      user.update(last_logout_at: Time.at(timestamp))
      AuditLog.create(
        user_id: user.id,
        action: 'logout',
        ip_address: ip_address,
        created_at: Time.at(timestamp)
      )

      Rails.logger.info "[UserLogout] User #{user.id} logged out from #{ip_address}"
    rescue => e
      handle_error(e)
    end
  end
end

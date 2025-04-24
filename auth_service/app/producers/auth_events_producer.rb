class AuthEventsProducer < ApplicationProducer
  def self.authentication_successful(user_id, token_data)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'authentication_successful',
        user_id: user_id,
        token: token_data[:token],
        expires_at: token_data[:expires_at],
        timestamp: Time.current
      }
    )
  end

  def self.authentication_failed(email, reason)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'authentication_failed',
        email: email,
        reason: reason,
        timestamp: Time.current
      }
    )
  end

  def self.token_refreshed(user_id, new_token_data)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'token_refreshed',
        user_id: user_id,
        token: new_token_data[:token],
        expires_at: new_token_data[:expires_at],
        timestamp: Time.current
      }
    )
  end

  def self.token_revoked(user_id)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'token_revoked',
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  def self.user_registered(user_id, email)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'user_registered',
        user_id: user_id,
        email: email,
        timestamp: Time.current
      }
    )
  end

  def self.user_logged_in(user_id, ip_address)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'user_logged_in',
        user_id: user_id,
        ip_address: ip_address,
        timestamp: Time.current
      }
    )
  end

  def self.user_logged_out(user_id)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'user_logged_out',
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  def self.password_reset_requested(user_id, email)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'password_reset_requested',
        user_id: user_id,
        email: email,
        timestamp: Time.current
      }
    )
  end

  def self.password_changed(user_id)
    call(
      topic: :auth_events,
      payload: {
        event_type: 'password_changed',
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end
end 
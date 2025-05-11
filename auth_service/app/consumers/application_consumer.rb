class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    raise NotImplementedError, "#{self.class} must implement consume method"
  end

  def get_user_locale(user_id)
    redis_client = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    locale = redis_client.hget("user:#{user_id}", "time_zone")

    # Если locale отсутствует или пустой, возвращаем значение по умолчанию
    locale && !locale.strip.empty? ? locale : "Moscow"
  end

  protected

  def find_user(user_id)
    User.find_by(id: user_id)
  end

  def log_event(event_name, payload)
    Rails.logger.info "[EVENT] #{event_name}: #{payload.to_json}"
  end
end
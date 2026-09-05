class UserProxy
  CACHE_TTL = 5.minutes.to_i

  # Явные методы для каждого поля — заменяет method_missing
  def discord_account
    check_redis_cache
    @cached_data['discord_account'] || fetch_from_service(:discord_account)
  end

  def minecraft_account
    check_redis_cache
    @cached_data['minecraft_account'] || fetch_from_service(:minecraft_account)
  end

  def updated_at
    check_redis_cache
    @cached_data['updated_at'] || fetch_from_service(:update)
  end

  def [](key)
    check_redis_cache
    @cached_data[key.to_s] || fetch_from_service(key)
  end

  def initialize(payload, current_user_id: nil)
    @payload = payload || {}
    @user_id = @payload.dig('user_id')
    @current_user_id = current_user_id
    @cached_data = @payload.dig('cached') || {}
  end

  def id
    @user_id
  end

  private

  def check_redis_cache
    @cached_data.merge!(REDIS_CLIENT.hgetall(redis_key))
  end

  def fetch_from_service(method)
    fields = case method.to_s
             when 'discord_account' then [:discord]
             when 'minecraft_account' then [:minecraft]
             when 'update' then [:updated_at]
             else [method]
             end

    if @user_id.blank?
      raise ArgumentError, "User ID is required for non-current user requests"
    end

    response = if @current_user_id && @user_id == @current_user_id
                 AuthClient.get("/api/v1/me/fields", query: { fields: fields })
               else
                 AuthClient.get("/api/v1/users/#{@user_id}/fields", query: { fields: fields })
               end

    handle_response(method, response)
  end

  def handle_response(method, response)
    unless response&.key?(method.to_s)
      log_error(method, response)
      return nil
    end

    value = response[method.to_s]
    cache_value(method, value)
    value
  end

  def cache_value(method, value)
    key = redis_key
    field = method.to_s
    # Последовательные вызовы вместо MULTI — MULTI не поддерживает вложенные блоки
    REDIS_CLIENT.hset(key, field, value.to_json)
    REDIS_CLIENT.expire(key, CACHE_TTL)
  end

  def log_error(method, response)
    Rails.logger.error <<~ERROR
      Failed to fetch field #{method} for user #{@user_id}
      Response: #{response.inspect}
      Backtrace: #{caller(0..3).join("\n")}
    ERROR
  end

  def redis_key
    "user:#{@user_id}:cache"
  end
end

class UserProxy
  CACHE_TTL = 5.minutes.to_i

  def initialize(payload, current_user_id: nil)
    @payload = payload || {}
    @user_id = @payload.dig('user_id')
    @current_user_id = current_user_id
    @cached_data = @payload.dig('cached') || {}
  end

  def id
    @user_id
  end

  def method_missing(method, *args)
    check_redis_cache
    @cached_data[method.to_s] || fetch_from_service(method)
  end

  private

  def check_redis_cache
    @cached_data.merge!(Redis.current.hgetall(redis_key))
  end

  def fetch_from_service(method)
    fields = case method.to_s
             when 'discord_account' then [:discord]
             when 'minecraft_account' then [:minecraft]
             when 'update' then [:updated_at] # Фикс для поля update
             else [method]
             end
  
    # Добавляем проверку ID
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

  def detect_fields(method)
    case method.to_s
    when 'discord_account' then [:discord]
    when 'minecraft_account' then [:minecraft]
    else [method]
    end
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
    Redis.current.multi do
      Redis.current.hset(redis_key, method.to_s, value.to_json)
      Redis.current.expire(redis_key, CACHE_TTL)
    end
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
require_relative '../../config/environment'

class UserUpdatesConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "Received #{messages.count} messages"
    
    messages.each do |message|
      begin
        data = message.payload
        Rails.logger.debug "Processing: #{data}"
        
        # Проверяем наличие user_id
        user_id = data['user_id']
        unless user_id
          Rails.logger.warn "Skipping message without user_id"
          next
        end
        
        # Обработка nil значений
        safe_data = replace_nil_with_empty(data)
        
        # Сохранение в Redis
        store_in_redis(user_id, safe_data)
      rescue => e
        Rails.logger.error "Error processing message: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end  
  end

  private

  def replace_nil_with_empty(obj)
    case obj
    when Hash
      obj.transform_values { |v| replace_nil_with_empty(v) }
    when Array
      obj.map { |e| replace_nil_with_empty(e) }
    when nil
      ""
    else
      obj
    end
  end

  def store_in_redis(user_id, data)
    # Вычисляем хэш-значение от данных обновления (например, MD5 от JSON)
    new_event_hash = Digest::MD5.hexdigest(data.to_json)
  
    user_key = "user_updates:#{user_id}"
    # Предполагаем, что можно получить последний сохранённый ключ, например:
    existing_updates = REDIS_CLIENT.hgetall(user_key)
    if existing_updates.present?
      latest_timestamp = existing_updates.keys.map(&:to_i).max.to_s
      latest_event = JSON.parse(existing_updates[latest_timestamp]) rescue {}
      # Вычисляем хэш последних данных (например, берём из поля data или updated_at)
      old_event_hash = Digest::MD5.hexdigest(latest_event["data"].to_json)
      # Если выявлена схожесть, можно просто вернуть
      return if new_event_hash == old_event_hash
    end
  
    # Если нет совпадения или обновлений нет, сохраняем новое событие
    timestamp = (Time.now.to_f * 1000).to_i
    REDIS_CLIENT.hset(
      user_key,
      timestamp,
      data.to_json
    )
  rescue => e
    Rails.logger.error "Redis error: #{e.message}"
    raise
  end  
end

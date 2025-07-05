class UserUpdateDataConsumer < Karafka::BaseConsumer
  BATCH_SIZE = 1_000

  def consume
    Rails.logger.info "[Karafka] Начинаем очистку таблицы ClickHouse: users"

    begin
      ClickHouse.connection.execute("TRUNCATE TABLE users")
    rescue => e
      Rails.logger.error "[Karafka] Ошибка при очистке таблицы users: #{e.message}"
      return
    end

    begin
      records_enum = enum_for(:all_user_records)
      total_inserted = 0

      records_enum.each_slice(BATCH_SIZE).with_index do |records_batch, idx|
        begin
          begin
            ClickHouse.connection.insert('users', records_batch)
          rescue => e
            Rails.logger.error "[Karafka] ❌ Ошибка вставки: #{e.message}"
            Rails.logger.debug "[Karafka] Данные: #{records_batch.inspect}"
          end
          total_inserted += records_batch.size
          Rails.logger.info "[Karafka] 🧩 Вставлена пачка ##{idx + 1}: #{records_batch.size} пользователей (всего: #{total_inserted})"
        rescue => e
          Rails.logger.error "[Karafka] ❌ Ошибка при вставке в ClickHouse (пачка ##{idx + 1}): #{e.message}"
        end
      end

      Rails.logger.info "[Karafka] ✅ Импорт завершён — всего записей вставлено: #{total_inserted}"
    rescue => e
      Rails.logger.error "[Karafka] ❌ Ошибка при вставке в ClickHouse: #{e.message}"
    end
  end

  private

  def all_user_records
    Rails.logger.info "[Karafka] 🚀 Начинаем генерацию записей пользователей"
    base_ts = (Time.now.to_f * 1000).to_i
    counter = 0

    User.includes(:discord_account, :minecraft_account, :issued_punishments)
      .find_each(batch_size: BATCH_SIZE) do |user|
        begin
          record = build_record(user, base_ts + counter)
          counter += 1
          yield record if record
        rescue => e
          Rails.logger.warn "[Karafka] ⚠️ Ошибка в сборке записи пользователя #{user.id}: #{e.message}"
        end
      end
  end

  def build_record(user, updated_ts)
    dc     = user.discord_account
    mc     = user.minecraft_account
    pun    = user.issued_punishments.where(active: true)
    status = determine_punishment_status(pun)

    {
      user_id:            user.id.to_s,
      discord_username:   format_discord_name(dc),
      minecraft_nickname: mc&.nickname.to_s,
      is_added:           user.is_added ? 1 : 0,
      punishment_status:  status,
      role_id:            user.role_id.to_i,
      discord_avatar_url: dc&.avatar.to_s,
      updated_at:         updated_ts
    }
  end

  def determine_punishment_status(active_punishments)
    return 1 if active_punishments.empty?

    types = active_punishments.pluck(:type)
    return 3 if types.include?('ban')
    return 2 if types.include?('mute')
    1
  end

  def format_discord_name(dc)
    return '' unless dc
    if dc.discriminator.present?
      "#{dc.username}##{dc.discriminator}"
    else
      dc.username
    end
  rescue => e
    Rails.logger.warn "[Karafka] ❌ Ошибка при форматировании Discord-имени: #{e.message}"
    ''
  end
end

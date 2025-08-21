# app/services/punishment_history_service.rb
class PunishmentHistoryService
  include Rails.application.routes.url_helpers

  def self.call(nickname)
    new(nickname).call
  end

  def initialize(nickname)
    @nickname = nickname.to_s.strip
    Rails.logger.debug "➡️ Получен nickname нарушителя: #{@nickname.inspect}"
  end

  def call
    account = find_account
    return { error: "Пользователь с ником #{@nickname} не найден" }, :not_found if account.nil?

    violator_id = account.user_id
    Rails.logger.debug "🔍 Найден bad_user_id (нарушитель): #{violator_id}"

    punishments = fetch_punishments(violator_id)
    cache_punishments(punishments)
    
    Rails.logger.debug "🚀 Финальный JSON для отдачи: #{punishments.inspect}"
    return punishments, :ok
  end

  private

  attr_reader :nickname

  def find_account
    account = MinecraftAccount.find_by(nickname: nickname)
    if account.nil?
      Rails.logger.warn "⚠️ Аккаунт Minecraft для '#{nickname}' не найден"
    end
    account
  end

  def fetch_punishments(violator_id)
    punishments_raw = UsersPunishment.where(user_id: violator_id).order(issued_at: :desc)
    Rails.logger.debug "📄 Найдено наказаний: #{punishments_raw.size}"

    punishments_raw.map do |punishment|
      process_punishment(punishment)
    end
  end

  def process_punishment(punishment)
    Rails.logger.debug "🔧 Обрабатывается наказание [#{punishment.type}] от #{punishment.issued_at}"
    
    issuer_info = build_issuer_info(punishment.user_id)
    final_price = determine_price(punishment)

    {
      id:          punishment.id,
      type:        punishment.type,
      reason:      punishment.punishment_reason&.description,
      issued_at:   punishment.issued_at,
      expires_at:  punishment.expires_at,
      status:      punishment.active,
      price:       final_price,
      issuer:      issuer_info
    }
  end

  def build_issuer_info(user_id)
    issuer_user     = User.find_by(id: user_id)
    issuer_nickname = MinecraftAccount.find_by(user_id: issuer_user&.id)&.nickname
    issuer_discord  = DiscordAccount.find_by(user_id: issuer_user&.id)
    
    Rails.logger.debug "👤 Наказание выдано пользователем ID=#{user_id} " \
                       "Minecraft=#{issuer_nickname.inspect} Discord=#{issuer_discord&.username}##{issuer_discord&.discriminator}"
    
    issuer_info = { user_id: user_id, nickname: issuer_nickname }
    
    if issuer_nickname.nil? && issuer_discord
      issuer_info[:discord_username]      = issuer_discord.username
      issuer_info[:discord_discriminator] = issuer_discord.discriminator
    end
    
    issuer_info
  end

  def determine_price(punishment)
    final_price = punishment.withdrawal_price
    rule_number = punishment.punishment_reason&.rule_number
    
    if final_price.blank? && rule_number.present?
      reason = PunishmentReason.find_by(rule_number: rule_number, punishment_type: punishment.type)
      if reason
        final_price = reason.price
        Rails.logger.debug "💰 Цена подтянута из punishment_reasons по rule_number=#{rule_number}: #{final_price}"
      else
        Rails.logger.warn "⚠️ Не найдена punishment_reason для rule_number=#{rule_number}, type=#{punishment.type}"
      end
    end
    
    final_price
  end

  def cache_punishments(punishments)
    redis_key = "punishment_history:#{nickname}"
    REDIS_CLIENT.setex(redis_key, 3.hours.to_i, punishments.to_json)
    Rails.logger.debug "✅ Наказания сохранены в Redis [#{redis_key}] на 3 часа"
  end
end

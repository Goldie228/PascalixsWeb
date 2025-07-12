require "ostruct"


module Api
  module V1
    class UserController < ApplicationController
      skip_before_action :authenticate_service_request, only: [ :public_profile, :punishment_history, :validate_password ]
      skip_before_action :verify_authenticity_token, only: [ :validate_password ]

      def public_profile
        nickname = params[:nickname].to_s.strip
        account  = MinecraftAccount.find_by(nickname: nickname)

        unless account
          render json: { error: "Пользователь с ником #{nickname} не найден" }, status: :not_found and return
        end

        user    = User.includes(:role).find_by(id: account.user_id)
        discord = DiscordAccount.find_by(user_id: user.id)

        result = OpenStruct.new(
          user_id: user.id,
          nickname: account.nickname,
          is_added: user.is_added,
          about_me: user.about_me,
          youtube_url: user.youtube_url,
          twitch_url: user.twitch_url,
          tiktok_url: user.tiktok_url,
          youtube_channel_name: user.youtube_channel_name,
          twitch_channel_name: user.twitch_channel_name,
          tiktok_channel_name: user.tiktok_channel_name,
          role_name: user.role&.name,
          role_color: user.role&.color,
          email: discord&.email,
          discord_account: discord ? OpenStruct.new(
            user_id: discord.user_id,
            discord_id: discord.discord_id,
            username: discord.username,
            discriminator: discord.discriminator,
            avatar: discord.avatar,
            email: discord.email
          ) : nil,
          minecraft_account: OpenStruct.new(
            nickname: account.nickname
          )
        )

        redis_key = "public_profile:#{nickname}"
        REDIS_CLIENT.setex(redis_key, 3.hours.to_i, result.to_h.to_json)

        render json: result.to_h, status: :ok
      end

      def punishment_history
        nickname = params[:nickname].to_s.strip
        Rails.logger.debug "➡️ Получен nickname нарушителя: #{nickname.inspect}"

        account = MinecraftAccount.find_by(nickname: nickname)
        if account.nil?
          Rails.logger.warn "⚠️ Аккаунт Minecraft для '#{nickname}' не найден"
          render json: { error: "Пользователь с ником #{nickname} не найден" }, status: :not_found and return
        end

        violator_id = account.user_id
        Rails.logger.debug "🔍 Найден bad_user_id (нарушитель): #{violator_id}"

        punishments_raw = UsersPunishment.where(user_id: violator_id).order(issued_at: :desc)
        Rails.logger.debug "📄 Найдено наказаний: #{punishments_raw.size}"

        punishments = punishments_raw.map do |punishment|
          Rails.logger.debug "🔧 Обрабатывается наказание [#{punishment.type}] от #{punishment.issued_at}"

          issuer_user = User.find_by(id: punishment.user_id)
          issuer_nickname = MinecraftAccount.find_by(user_id: issuer_user&.id)&.nickname
          issuer_discord  = DiscordAccount.find_by(user_id: issuer_user&.id)

          Rails.logger.debug "👤 Наказание выдано пользователем ID=#{punishment.user_id} " \
                             "Minecraft=#{issuer_nickname.inspect} Discord=#{issuer_discord&.username}##{issuer_discord&.discriminator}"

          issuer_info = {
            user_id: punishment.user_id,
            nickname: issuer_nickname
          }

          if issuer_nickname.nil? && issuer_discord
            issuer_info[:discord_username] = issuer_discord.username
            issuer_info[:discord_discriminator] = issuer_discord.discriminator
          end

          {
            type: punishment.type,
            reason: punishment.reason,
            issued_at: punishment.issued_at,
            expires_at: punishment.expires_at,
            status: punishment.active,
            issuer: issuer_info
          }
        end

        redis_key = "punishment_history:#{nickname}"
        REDIS_CLIENT.setex(redis_key, 3.hours.to_i, punishments.to_json)
        Rails.logger.debug "✅ Наказания сохранены в Redis [#{redis_key}] на 3 часа"

        Rails.logger.debug "🚀 Финальный JSON для отдачи: #{punishments.inspect}"
        render json: punishments, status: :ok
      end

      def validate_password
        nickname = params[:nickname].to_s.strip
        plain_password = params[:password].to_s

        if plain_password.blank?
          render json: { error: "Пароль не может быть пустым" }, status: :unprocessable_entity and return
        end

        account = MinecraftAccount.find_by(nickname: nickname)

        if account.nil?
          render json: { error: "Пользователь с ником #{nickname} не найден" }, status: :not_found and return
        end

        validator = MinecraftAccount.new(password: plain_password, password_confirmation: plain_password)
        validator.valid?

        unless validator.errors[:password].present?
          render json: { hash: validator.hash_password }, status: :ok
        else
          render json: { error: "Пароль не прошёл проверку" }, status: :unprocessable_entity
        end
      end
    end
  end
end

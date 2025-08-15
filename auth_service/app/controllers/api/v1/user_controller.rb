require "ostruct"
require "digest"


module Api
  module V1
    class UserController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [ :validate_password ]

      def get_user_data
        user_id = params["user_id"]
        Rails.logger.info "📡 Запрос данных для пользователя: user_id=#{user_id}"

        user = User.find_by(id: user_id)

        if user.blank?
          Rails.logger.warn "❌ Пользователь с id=#{user_id} не найден"
          render json: { error: "Пользователь не найден" }, status: :not_found
          return
        end

        # Обновляем данные
        UserDataProducer.publish(user)
        Rails.logger.info "📨 Данные отправлены в Redis через UserDataProducer"

        user_key = "user_updates:#{user_id}"
        updates = REDIS_CLIENT.hgetall(user_key)

        Rails.logger.debug "🔍 updates = #{updates.inspect}"
        Rails.logger.debug "🔍 keys in updates = #{updates.keys.inspect}"

        if updates.blank?
          Rails.logger.warn "⚠️ Нет данных в Redis для user_id=#{user_id}"
          render json: { error: "Данные отсутствуют" }, status: :service_unavailable
          return
        end

        # Получаем самую свежую версию по таймстампу
        latest_timestamp = updates.keys.map(&:to_i).max.to_s
        Rails.logger.debug "🔍 latest_timestamp = #{latest_timestamp}"

        raw_data = updates[latest_timestamp]

        begin
          parsed_data = JSON.parse(raw_data)
          render json: parsed_data
        rescue => e
          Rails.logger.error "❌ Ошибка парсинга Redis-данных: #{e.message}"
          render json: { error: "Ошибка данных" }, status: :internal_server_error
        end
      end

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
          is_sponsor: user.is_sponsor,
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
            id: punishment.id,
            type: punishment.type,
            reason: punishment.punishment_reason&.description,
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
          render json: { error: validator.errors.full_messages_for(:password).first }, status: :unprocessable_entity
        end
      end

      def get_password
        user_id = params[:user_id].to_s.strip

        if user_id.blank?
          Rails.logger.warn "⚠️ user_id не передан"
          render json: { error: "user_id обязателен" }, status: :bad_request and return
        end

        account = MinecraftAccount.find_by(user_id: user_id)

        if account.nil?
          Rails.logger.warn "🔍 Аккаунт не найден для user_id=#{user_id}"
          render json: { error: "Аккаунт не найден" }, status: :not_found and return
        end

        Rails.logger.debug "🔐 Возврат хеша пароля: user_id=#{user_id}, hash=#{account.password_hash}"

        render json: {
          hash: account.password_hash
        }, status: :ok
      end

      def password_check
        nickname = params[:nickname].to_s.strip
        plain_password = request.headers['X-Password'].to_s.strip

        if nickname.blank? || plain_password.blank?
          render json: {
            error: "missing_parameters",
            message: "Nickname и X-Password header обязательны"
          }, status: :bad_request and return
        end

        minecraft_account = MinecraftAccount.find_by(nickname: nickname)

        unless minecraft_account
          render json: {
            error: "not_found",
            message: "MinecraftAccount не найден"
          }, status: :not_found and return
        end

        stored_hash = minecraft_account.password_hash

        if stored_hash.start_with?("$SHA$")
          _, _, salt, hash = stored_hash.split("$")
          input_hash = Digest::SHA256.hexdigest(
            Digest::SHA256.hexdigest(plain_password) + salt
          )

          if ActiveSupport::SecurityUtils.secure_compare(input_hash, hash)
            render json: { success: true, message: "Пароль совпадает" }, status: :ok
          else
            render json: { success: false, error: "Пароль неверен" }, status: :unauthorized
          end
        else
          render json: { error: "Неподдерживаемый формат хэша" }, status: :unprocessable_entity
        end
      end

      def set_email
        new_email = request.headers['X-Email'] || params[:email]

        if new_email.blank?
          render json: { error: "Email is required" }, status: :bad_request
          return
        end

        unless URI::MailTo::EMAIL_REGEXP.match?(new_email)
          render json: { error: "Invalid email format" }, status: :unprocessable_entity
          return
        end

        # Проверяем, не используется ли email другим пользователем
        if DiscordAccount.where(email: new_email).where.not(user_id: @user.id).exists?
          render json: { error: "Email is already taken" }, status: :conflict
          return
        end

        ActiveRecord::Base.transaction do
          # Обновляем email в Discord аккаунте
          discord_account = @user.discord_account
          discord_account.update!(email: new_email)

          # Здесь можно добавить отправку письма подтверждения
          UserMailer.email_changed(@user, new_email).deliver_later

          render json: {
            success: true,
            message: "Email updated successfully",
            new_email: new_email
          }, status: :ok
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue => e
        render json: { error: "Failed to update email: #{e.message}" }, status: :internal_server_error
      end

      def lookup_email
        email = request.headers['X-Email']

        # Проверка, что email передан
        if email.blank?
          render json: { error: "Email обязателен" }, status: :bad_request and return
        end

        # Проверка формата email
        unless URI::MailTo::EMAIL_REGEXP.match?(email)
          render json: { error: "Неверный формат email" }, status: :unprocessable_entity and return
        end

        # Поиск аккаунта
        discord = DiscordAccount.find_by(email: email)

        unless discord
          render json: { error: "Пользователь с таким email не найден" }, status: :not_found and return
        end

        # Получаем никнейм из Minecraft аккаунта
        minecraft = MinecraftAccount.find_by(user_id: discord.user_id)

        render json: {
          success: true,
          user_id: discord.user_id,
          nickname: minecraft&.nickname || nil
        }, status: :ok
      end

      private

      def find_player
        nickname = params[:nickname]
        @minecraft_account = MinecraftAccount.find_by(nickname: nickname)

        unless @minecraft_account
          render json: { error: "Player not found" }, status: :not_found
          return
        end

        @user = User.find_by(id: @minecraft_account.user_id)
        unless @user
          render json: { error: "User not found" }, status: :not_found
          return
        end

        unless @user.discord_account
          render json: { error: "Discord account not linked" }, status: :unprocessable_entity
        end
      end
    end
  end
end

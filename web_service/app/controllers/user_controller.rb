class UserController < ApplicationController
  before_action :require_login

  def show
    require_login

    @nickname = nil

    user_id = current_user.id

    if current_user.minecraft_account&.present?
      @nickname = current_user.minecraft_account.nickname
      Rails.logger.debug "Получен Minecraft ник: #{@nickname}"

      unless REDIS_CLIENT.hget("punishments:#{user_id}", "data").present?
        produce_with_retries(
          "get_user_punishments",
          { user_id: user_id }
        )
      end

       McOnlineStatusJob.perform_later(nickname: @nickname, user_id: user_id)
    end

    @is_banned = is_banned?(user_id)

    if @nickname.present?
      redis_key = "player_roles:#{@nickname}"

      redis_data = REDIS_CLIENT.get(redis_key)

      unless redis_data.present?
        produce_with_retries("minecraft_service_get_roles", payload: { nickname: @nickname })

        max_attempts = 3
        attempt = 0
        redis_data = nil

        while attempt < max_attempts
          sleep 1
          redis_data = REDIS_CLIENT.get(redis_key)
          break if redis_data.present?
          attempt += 1
        end
      end

      if redis_data.present?
        roles_hash = JSON.parse(redis_data)
        @mc_roles = roles_hash.transform_keys { |k| k.to_i }
        Rails.logger.debug "Получены данные ролей из Redis: #{@mc_roles.inspect}"
      else
        @mc_roles = {}
        Rails.logger.info("Данные ролей для #{@nickname} не найдены в Redis после #{max_attempts} попыток")
      end
    else
      @mc_roles = {}
      Rails.logger.info("Не задан nickname, поэтому роли не запрашиваются")
    end

    @web_role = current_user.role_name
    @web_role_color = current_user.role_color
  end

  def update_about_me
    about_me = params[:about_me_text]
    user_id = current_user.id

    if about_me.present? && current_user.present?
      produce_with_retries(
        "auth_service_set_about_me",
        payload: {
          user_id: user_id,
          about_me: about_me
        }
      )
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if user_data["about_me"] == about_me

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    redirect_to user_profile_path
  end

  def youtube_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_youtube_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["youtube_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  def tiktok_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_tiktok_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["tiktok_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  def twitch_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_twitch_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["twitch_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  private

  def is_banned?(user_id)
    punishments = fetch_punishments(user_id)

    punishments.any? { |p| p["type"].to_s.downcase == "ban" }
  end

  def fetch_punishments(user_id)
    punishments_json = REDIS_CLIENT.hget("punishments:#{user_id}", "data")
    return [] unless punishments_json.present?

    JSON.parse(punishments_json)
  rescue JSON::ParserError => e
    Rails.logger.error "Ошибка парсинга наказаний для #{user_id}: #{e.message}"
    []
  end

  def require_login
    unless current_user
      redirect_to login_path, alert: t("controllers.auth.unauthorized")
    end
  end
end

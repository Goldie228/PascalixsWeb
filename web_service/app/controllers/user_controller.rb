class UserController < ApplicationController
  def show
    require_login

    @nickname = nil
    if current_user.minecraft_account&.present?
      @nickname = current_user.minecraft_account.nickname
      Rails.logger.debug "Получен Minecraft ник: #{@nickname}"
      McOnlineStatusJob.perform_async(@nickname)
    end

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

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: t("controllers.auth.unauthorized")
    end
  end
end

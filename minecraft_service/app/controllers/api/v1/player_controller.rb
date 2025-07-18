module Api
  module V1
    class PlayerController < ApplicationController
      def check_password
        nickname = params[:nickname].to_s.strip
        password = params[:password].to_s.strip

        if nickname.blank? || password.blank?
          render json: { error: "missing_parameters", message: "Nickname и password обязательны" }, status: :bad_request
          return
        end

        record = Authme.find_by(realname: nickname)

        if record.nil?
          Rails.logger.warn("🔍 Аккаунт не найден: realname=#{nickname}")
          render json: { error: "not_found", message: "Игрок с таким ником не найден" }, status: :not_found
          return
        end

        if password == record.password
          render json: { status: "ok", message: "Пароль совпадает" }, status: :ok
        else
          Rails.logger.warn("❌ Неверный пароль для: #{nickname}")
          render json: {
            error: "invalid_password",
            message: "Пароль неверен",
            correct_hash: record.password
          }, status: :unauthorized
        end
      end
    end
  end
end

module Api
  module V1
    class DropedUserController < ApplicationController
      skip_before_action :authenticate_service_request
      skip_before_action :verify_authenticity_token, only: [ :add ]

      def all
        removed_players = DropedUser.all

        render json: removed_players.map { |player|
          {
            nickname: player.name,
            deleted_at: player.created_at
          }
        }
      end

      def add
        nickname = params[:nickname].to_s.strip

        user = DropedUser.new(name: nickname)

        if DropedUser.exists?(name: nickname)
          render json: { error: "already_exists" }, status: :unprocessable_entity
          return
        end

        unless user.valid?
          if nickname.blank? || nickname.length < 3
            render json: { error: "nickname_invalid" }, status: :unprocessable_entity
          else
            render json: { error: "invalid_data", details: user.errors.full_messages }, status: :unprocessable_entity
          end
          return
        end

        user.save!
        render json: { status: "ok", nickname: nickname }

      rescue => e
        Rails.logger.error "[AddRemovedPlayer] Ошибка: #{e.message}\n#{e.backtrace.take(5).join("\n")}"
        render json: { error: "server_error" }, status: :unprocessable_entity
      end
    end
  end
end

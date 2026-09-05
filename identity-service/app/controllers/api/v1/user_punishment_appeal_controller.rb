module Api
  module V1
    class UserPunishmentAppealController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [ :delete, :admin_reject ]

      def get_punishment_appeal
        punishment_id = params[:id]
        appeal = UserPunishmentAppeal.find_by(punishment_id: punishment_id)

        if appeal
          render json: {
            appeal: {
              status: appeal.status,
              can_repeal: appeal.can_reappeal,
              message: appeal.user_message,
              admin_comment: appeal.admin_comment
            }
          }, status: :ok
        else
          render json: {
            appeal: {
              status: "",
              can_repeal: true,
              message: "",
              admin_comment: ""
            }
          }, status: :ok
        end
      end

      def all
        page = (params[:page] || 1).to_i.clamp(1, 10_000)
        per_page = (params[:per_page] || 25).to_i.clamp(1, 100)

        allowed_sorts = %w[nickname type status can_reappeal created_at]
        sort_key = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'created_at'
        order_dir = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'

        search_term = params[:search].to_s.strip.downcase

        begin
          # Базовый запрос без селекта
          base_query = UserPunishmentAppeal.joins(
            punishment: { bad_user: :minecraft_account }
          )

          # Применяем поисковый фильтр сразу к базовому запросу
          if search_term.present?
            base_query = base_query.where(
              'LOWER(minecraft_accounts.nickname) LIKE :search OR ' \
              'LOWER(users_punishments.type) LIKE :search OR ' \
              'LOWER(user_punishment_appeals.status) LIKE :search',
              search: "%#{search_term}%"
            )
          end

          # Подсчет общего количества ДО применения селекта и сортировки
          total_count = base_query.count

          # Теперь строим запрос для выборки данных
          query = base_query.select(
            'user_punishment_appeals.punishment_id AS id',
            'minecraft_accounts.nickname AS nickname',
            'users_punishments.type AS type',
            'user_punishment_appeals.status AS status',
            'user_punishment_appeals.can_reappeal AS can_reappeal',
            'user_punishment_appeals.created_at AS created_at'
          )

          # Применяем сортировку
          case sort_key
          when 'nickname'
            query = query.order("LOWER(minecraft_accounts.nickname) #{order_dir}")
          when 'type'
            query = query.order("users_punishments.type #{order_dir}")
          when 'status'
            query = query.order("user_punishment_appeals.status #{order_dir}")
          when 'can_reappeal'
            query = query.order("user_punishment_appeals.can_reappeal #{order_dir}")
          when 'created_at'
            query = query.order("user_punishment_appeals.created_at #{order_dir}")
          else
            query = query.order("user_punishment_appeals.created_at DESC")
          end

          # Применяем пагинацию
          appeals = query.offset((page - 1) * per_page).limit(per_page)

          formatted_appeals = appeals.map do |appeal|
            {
              id: appeal.id,
              nickname: appeal.nickname,
              type: appeal.type,
              status: appeal.status,
              can_reappeal: appeal.can_reappeal == true
            }
          end

          render json: {
            appeals: formatted_appeals,
            total_count: total_count,
            page: page,
            per_page: per_page,
            total_pages: (total_count / per_page.to_f).ceil
          }, status: :ok

        rescue => e
          Rails.logger.error "Ошибка в методе all: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          render json: {
            error: "Внутренняя ошибка сервера",
            message: e.message
          }, status: :internal_server_error
        end
      end

      def show
        punishment_id = params[:id].to_i

        appeal = UserPunishmentAppeal
                   .includes(punishment: { bad_user: :minecraft_account, punishment_reason: {} })
                   .find_by(punishment_id: punishment_id)

        unless appeal
          return render json: { error: "Appeal not found" }, status: :not_found
        end

        punishment  = appeal.punishment
        bad_user    = punishment.bad_user
        mc_account  = bad_user&.minecraft_account

        reason_text =
          punishment.try(:reason_description).presence ||
          punishment.punishment_reason&.description.presence ||
          "—"

        render json: {
          player_name:       mc_account&.nickname || "Unknown",
          punishment_type:   punishment.type,
          punishment_reason: reason_text,
          appeal_date:       appeal.created_at.to_date.strftime("%Y-%m-%d"),
          appeal_message:    appeal.user_message
        }, status: :ok
      end

      def delete
        punishment_id = params[:id].to_i

        appeal = UserPunishmentAppeal.find_by(punishment_id: punishment_id)
        punishment = UsersPunishment.find_by(id: punishment_id)

        unless appeal || punishment
          return render json: { error: "Ничего не найдено для обработки" }, status: :not_found
        end

        begin
          appeal&.destroy
          punishment&.update!(active: false)

          render json: { success: true }
        rescue => e
          Rails.logger.error("Ошибка при обновлении/удалении для ID #{punishment_id}: #{e.message}")
          render json: { success: false, error: "Ошибка при обработке" }, status: :internal_server_error
        end
      end

      def get_admin_answer
        punishment_id = params[:id].to_i
        appeal = UserPunishmentAppeal.find_by(punishment_id: punishment_id)

        if appeal
          render json: {
            admin_comment: appeal.admin_comment || "",
            can_reappeal: appeal.can_reappeal
          }, status: :ok
        else
          render json: {
            admin_comment: "",
            can_reappeal: true
          }, status: :ok
        end
      end

      def admin_reject
        begin
          data = JSON.parse(request.body.read)

          punishment_id = data["punishment_id"].to_i
          admin_comment = data["admin_comment"] || ""
          can_reappeal = data["can_reappeal"]

          appeal = UserPunishmentAppeal.find_by(punishment_id: punishment_id)

          unless appeal
            return render json: { success: false, error: "Апелляция не найдена" }, status: :not_found
          end

          appeal.update!(
            admin_comment: admin_comment,
            can_reappeal: can_reappeal,
            status: "rejected"
          )

          render json: { success: true }
        rescue => e
          Rails.logger.error("Ошибка при отклонении апелляции для punishment_id=#{data['punishment_id']}: #{e.message}")
          render json: { success: false, error: "Ошибка обработки данных" }, status: :internal_server_error
        end
      end
    end
  end
end

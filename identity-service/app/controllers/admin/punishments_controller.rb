module Admin
  class PunishmentsController < ApplicationController
    before_action :authenticate_admin!
    skip_before_action :authenticate_user!

    # GET /api/v1/admin/punishments
    def index
      page = (params[:page] || 1).to_i.clamp(1, 10_000)
      per_page = [([params[:per_page] || 20].to_i.clamp(1, 100)), 100].min

      punishments = UsersPunishment.includes(
        :bad_user,
        :user,
        :punishment_reason
      ).order(issued_at: :desc)
       .page(page)
       .per(per_page)

      render json: {
        punishments: punishments.map do |p|
          {
            id: p.id,
            user_id: p.user_id,
            bad_user_id: p.bad_user_id,
            bad_user_nickname: p.bad_user&.minecraft_account&.nickname,
            bad_user_discord: p.bad_user&.discord_account&.username,
            type: p.type,
            reason: p.reason_description,
            rule_number: p.punishment_reason&.rule_number,
            issuer_id: p.user_id,
            issued_at: p.issued_at.iso8601,
            expires_at: p.expires_at&.iso8601,
            active: p.active,
            duration: p.duration,
            withdrawal_price: p.withdrawal_price
          }
        end,
        meta: {
          current_page: punishments.current_page,
          total_pages: punishments.total_pages,
          total_count: punishments.total_count,
          per_page: per_page
        }
      }
    end

    # GET /api/v1/admin/punishments/:id
    def show
      punishment = UsersPunishment.includes(
        :bad_user,
        :user,
        :punishment_reason
      ).find_by(id: params[:id])

      return render json: { error: 'Punishment not found' }, status: :not_found unless punishment

      render json: {
        id: punishment.id,
        user_id: punishment.user_id,
        bad_user_id: punishment.bad_user_id,
        bad_user_nickname: punishment.bad_user&.minecraft_account&.nickname,
        bad_user_discord: punishment.bad_user&.discord_account&.username,
        type: punishment.type,
        reason: punishment.reason_description,
        rule_number: punishment.punishment_reason&.rule_number,
        issuer_id: punishment.user_id,
        issued_at: punishment.issued_at.iso8601,
        expires_at: punishment.expires_at&.iso8601,
        active: punishment.active,
        duration: punishment.duration,
        withdrawal_price: punishment.withdrawal_price
      }
    end

    # POST /api/v1/admin/punishments
    def create
      punishment = UsersPunishment.new(punishment_params)

      if punishment.save
        Rails.logger.info("Admin #{admin_id} issued #{punishment.type} punishment to user #{punishment.bad_user_id}: #{punishment.reason_description}")

        # Publish Kafka event
        ApplicationProducer.call(
          topic: 'identity.punishment.issued',
          payload: {
            user_id: punishment.bad_user_id,
            type: punishment.type,
            reason: punishment.reason_description,
            issuer_id: punishment.user_id,
            expires_at: punishment.expires_at&.iso8601,
            punishment_id: punishment.id
          }
        )

        render json: {
          id: punishment.id,
          user_id: punishment.user_id,
          bad_user_id: punishment.bad_user_id,
          bad_user_nickname: punishment.bad_user&.minecraft_account&.nickname,
          type: punishment.type,
          reason: punishment.reason_description,
          rule_number: punishment.punishment_reason&.rule_number,
          issuer_id: punishment.user_id,
          issued_at: punishment.issued_at.iso8601,
          expires_at: punishment.expires_at&.iso8601,
          active: punishment.active,
          duration: punishment.duration
        }, status: :created
      else
        render json: { error: punishment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v1/admin/punishments/:id/resolve
    def resolve
      punishment = UsersPunishment.find_by(id: params[:id])
      return render json: { error: 'Punishment not found' }, status: :not_found unless punishment
      return render json: { error: 'Punishment is not active' }, status: :bad_request unless punishment.active

      punishment.update!(active: false)

      Rails.logger.info("Admin #{admin_id} resolved punishment #{punishment.id} for user #{punishment.bad_user_id}")

      # Publish Kafka event
      ApplicationProducer.call(
        topic: 'identity.punishment.resolved',
        payload: {
          user_id: punishment.bad_user_id,
          type: punishment.type,
          issuer_id: punishment.user_id,
          punishment_id: punishment.id
        }
      )

      render json: {
        id: punishment.id,
        user_id: punishment.user_id,
        bad_user_id: punishment.bad_user_id,
        type: punishment.type,
        reason: punishment.reason_description,
        issuer_id: punishment.user_id,
        issued_at: punishment.issued_at.iso8601,
        expires_at: punishment.expires_at&.iso8601,
        active: punishment.active
      }
    end

    private

    def punishment_params
      params.require(:punishment).permit(
        :bad_user_id,
        :user_id,
        :type,
        :punishment_reason_id,
        :issued_at,
        :expires_at,
        :duration,
        :withdrawal_price
      )
    end

    def admin_id
      request.headers['X-User-ID']
    end
  end
end

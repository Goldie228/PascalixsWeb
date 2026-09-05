module Admin
  class AppealsController < ApplicationController
    before_action :authenticate_admin!
    skip_before_action :authenticate_user!

    # GET /api/v1/admin/appeals
    def index
      page = (params[:page] || 1).to_i.clamp(1, 10_000)
      per_page = [([params[:per_page] || 20].to_i.clamp(1, 100)), 100].min

      appeals = UserPunishmentAppeal.includes(
        punishment: { bad_user: :minecraft_account }
      ).order(created_at: :desc)
       .page(page)
       .per(per_page)

      render json: {
        appeals: appeals.map do |a|
          punishment = a.punishment
          bad_user = punishment&.bad_user
          mc_account = bad_user&.minecraft_account

          {
            id: a.id,
            punishment_id: a.punishment_id,
            user_id: bad_user&.id,
            player_nickname: mc_account&.nickname,
            punishment_type: punishment&.type,
            reason: punishment&.reason_description,
            status: a.status,
            user_message: a.user_message,
            admin_comment: a.admin_comment,
            can_reappeal: a.can_reappeal,
            created_at: a.created_at.iso8601,
            updated_at: a.updated_at.iso8601
          }
        end,
        meta: {
          current_page: appeals.current_page,
          total_pages: appeals.total_pages,
          total_count: appeals.total_count,
          per_page: per_page
        }
      }
    end

    # GET /api/v1/admin/appeals/:id
    def show
      appeal = UserPunishmentAppeal.includes(
        punishment: { bad_user: [:minecraft_account, :discord_account], punishment_reason: {} }
      ).find_by(id: params[:id])

      return render json: { error: 'Appeal not found' }, status: :not_found unless appeal

      punishment = appeal.punishment
      bad_user = punishment&.bad_user
      mc_account = bad_user&.minecraft_account

      render json: {
        id: appeal.id,
        punishment_id: appeal.punishment_id,
        user_id: bad_user&.id,
        player_nickname: mc_account&.nickname,
        player_discord: bad_user&.discord_account&.username,
        punishment_type: punishment&.type,
        punishment_reason: punishment&.reason_description,
        rule_number: punishment&.punishment_reason&.rule_number,
        status: appeal.status,
        user_message: appeal.user_message,
        admin_comment: appeal.admin_comment,
        can_reappeal: appeal.can_reappeal,
        created_at: appeal.created_at.iso8601,
        updated_at: appeal.updated_at.iso8601
      }
    end

    # PATCH /api/v1/admin/appeals/:id/approve
    def approve
      appeal = UserPunishmentAppeal.find_by(id: params[:id])
      return render json: { error: 'Appeal not found' }, status: :not_found unless appeal
      return render json: { error: 'Appeal already reviewed' }, status: :bad_request unless appeal.pending?

      appeal.update!(
        status: 'accepted',
        admin_comment: params[:admin_comment],
        can_reappeal: false
      )

      # Resolve punishment
      punishment = UsersPunishment.find_by(id: appeal.punishment_id)
      punishment&.update!(active: false)

      Rails.logger.info("Admin #{admin_id} approved appeal #{appeal.id} for punishment #{appeal.punishment_id}")

      # Publish Kafka event
      ApplicationProducer.call(
        topic: 'identity.appeal.approved',
        payload: {
          appeal_id: appeal.id,
          punishment_id: appeal.punishment_id,
          user_id: punishment&.bad_user_id,
          admin_id: admin_id
        }
      )

      render json: {
        id: appeal.id,
        punishment_id: appeal.punishment_id,
        status: appeal.status,
        admin_comment: appeal.admin_comment,
        can_reappeal: appeal.can_reappeal,
        updated_at: appeal.updated_at.iso8601
      }
    end

    # PATCH /api/v1/admin/appeals/:id/reject
    def reject
      appeal = UserPunishmentAppeal.find_by(id: params[:id])
      return render json: { error: 'Appeal not found' }, status: :not_found unless appeal
      return render json: { error: 'Appeal already reviewed' }, status: :bad_request unless appeal.pending?

      appeal.update!(
        status: 'rejected',
        admin_comment: params[:admin_comment],
        can_reappeal: params[:can_reappeal] != false
      )

      Rails.logger.info("Admin #{admin_id} rejected appeal #{appeal.id} for punishment #{appeal.punishment_id}")

      # Publish Kafka event
      ApplicationProducer.call(
        topic: 'identity.appeal.rejected',
        payload: {
          appeal_id: appeal.id,
          punishment_id: appeal.punishment_id,
          user_id: appeal.punishment&.bad_user_id,
          admin_id: admin_id
        }
      )

      render json: {
        id: appeal.id,
        punishment_id: appeal.punishment_id,
        status: appeal.status,
        admin_comment: appeal.admin_comment,
        can_reappeal: appeal.can_reappeal,
        updated_at: appeal.updated_at.iso8601
      }
    end

    private

    def admin_id
      request.headers['X-User-ID']
    end
  end
end

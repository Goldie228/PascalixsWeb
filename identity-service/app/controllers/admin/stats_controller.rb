module Admin
  class StatsController < ApplicationController
    before_action :authenticate_admin!
    skip_before_action :authenticate_user!

    # GET /api/v1/admin/stats/overview
    def overview
      render json: {
        users: {
          total: User.count,
          added: User.where(is_added: true).count,
          sponsors: User.where(is_sponsor: true).count,
          created_today: User.where(created_at: Time.now.beginning_of_day..Time.now).count
        },
        punishments: {
          total: UsersPunishment.count,
          active: UsersPunishment.where(active: true).count,
          resolved: UsersPunishment.where(active: false).count,
          issued_today: UsersPunishment.where(issued_at: Time.now.beginning_of_day..Time.now).count
        },
        recent_activity: {
          users: User.includes(:role, :discord_account)
                     .order(created_at: :desc)
                     .limit(10)
                     .map do |u|
            {
              id: u.id,
              discord_username: u.discord_account&.username,
              role_name: u.role&.name,
              created_at: u.created_at.iso8601
            }
          end,
          punishments: UsersPunishment.includes(:bad_user)
                                      .order(issued_at: :desc)
                                      .limit(10)
                                      .map do |p|
            {
              id: p.id,
              bad_user_nickname: p.bad_user&.minecraft_account&.nickname,
              type: p.type,
              reason: p.reason_description,
              issued_at: p.issued_at.iso8601
            }
          end
        }
      }
    end

    # GET /api/v1/admin/stats/users/:user_id
    def user_stats
      user = User.includes(:role, :discord_account, :minecraft_account).find_by(id: params[:user_id])
      return render json: { error: 'User not found' }, status: :not_found unless user

      render json: {
        user: {
          id: user.id,
          discord_username: user.discord_account&.username,
          minecraft_nickname: user.minecraft_account&.nickname,
          role_name: user.role&.name,
          role_color: user.role&.color,
          created_at: user.created_at.iso8601
        },
        punishments: {
          total: UsersPunishment.where(bad_user_id: user.id).count,
          active: UsersPunishment.where(bad_user_id: user.id, active: true).count,
          resolved: UsersPunishment.where(bad_user_id: user.id, active: false).count
        },
        recent_punishments: UsersPunishment.includes(:punishment_reason)
                                           .where(bad_user_id: user.id)
                                           .order(issued_at: :desc)
                                           .limit(10)
                                           .map do |p|
          {
            id: p.id,
            type: p.type,
            reason: p.reason_description,
            issuer_id: p.user_id,
            issued_at: p.issued_at.iso8601,
            expires_at: p.expires_at&.iso8601,
            active: p.active
          }
        end
      }
    end
  end
end

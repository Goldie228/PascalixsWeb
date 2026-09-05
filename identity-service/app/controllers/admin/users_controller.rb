module Admin
  class UsersController < ApplicationController
    before_action :authenticate_admin!
    skip_before_action :authenticate_user!

    # GET /api/v1/admin/users
    def index
      page = (params[:page] || 1).to_i.clamp(1, 10_000)
      per_page = [([params[:per_page] || 20].to_i.clamp(1, 100)), 100].min

      users = User.includes(:role, :discord_account, :minecraft_account)
                  .order(created_at: :desc)
                  .page(page)
                  .per(per_page)

      render json: {
        users: users.map do |u|
          {
            id: u.id,
            discord_username: u.discord_account&.username,
            discord_avatar_url: u.discord_account&.avatar,
            minecraft_nickname: u.minecraft_account&.nickname,
            role_name: u.role&.name,
            role_color: u.role&.color,
            role_id: u.role_id,
            is_added: u.is_added,
            is_sponsor: u.is_sponsor,
            about_me: u.about_me,
            created_at: u.created_at.iso8601,
            updated_at: u.updated_at.iso8601
          }
        end,
        meta: {
          current_page: users.current_page,
          total_pages: users.total_pages,
          total_count: users.total_count,
          per_page: per_page
        }
      }
    end

    # GET /api/v1/admin/users/:id
    def show
      user = User.includes(:role, :discord_account, :minecraft_account).find_by(id: params[:id])
      return render json: { error: 'User not found' }, status: :not_found unless user

      render json: {
        id: user.id,
        discord_username: user.discord_account&.username,
        discord_avatar_url: user.discord_account&.avatar,
        minecraft_nickname: user.minecraft_account&.nickname,
        role_name: user.role&.name,
        role_color: user.role&.color,
        role_id: user.role_id,
        is_added: user.is_added,
        is_sponsor: user.is_sponsor,
        about_me: user.about_me,
        youtube_url: user.youtube_url,
        twitch_url: user.twitch_url,
        tiktok_url: user.tiktok_url,
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      }
    end

    # PATCH /api/v1/admin/users/:id
    def update
      user = User.find_by(id: params[:id])
      return render json: { error: 'User not found' }, status: :not_found unless user

      if user.update(update_params)
        Rails.logger.info("Admin #{admin_id} updated user #{user.id}: role=#{user.role_id}, is_added=#{user.is_added}, is_sponsor=#{user.is_sponsor}")

        render json: {
          id: user.id,
          discord_username: user.discord_account&.username,
          minecraft_nickname: user.minecraft_account&.nickname,
          role_name: user.role&.name,
          role_color: user.role&.color,
          role_id: user.role_id,
          is_added: user.is_added,
          is_sponsor: user.is_sponsor,
          updated_at: user.updated_at.iso8601
        }
      else
        render json: { error: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v1/admin/users/:id
    def destroy
      user = User.find_by(id: params[:id])
      return render json: { error: 'User not found' }, status: :not_found unless user

      user.destroy
      Rails.logger.info("Admin #{admin_id} deleted user #{user.id}")

      render json: { message: 'User deleted' }
    end

    # GET /api/v1/admin/users/search?q=query
    def search
      query = params[:q].to_s.strip
      return render json: { error: 'Query parameter required' }, status: :bad_request if query.blank?

      users = User.includes(:role, :discord_account, :minecraft_account)
                  .where(
                    'LOWER(discord_accounts.username) LIKE :q OR LOWER(minecraft_accounts.nickname) LIKE :q',
                    q: "%#{query.downcase}%"
                  )
                  .limit(20)

      render json: {
        users: users.map do |u|
          {
            id: u.id,
            discord_username: u.discord_account&.username,
            minecraft_nickname: u.minecraft_account&.nickname,
            role_name: u.role&.name
          }
        end
      }
    end

    private

    def update_params
      params.require(:user).permit(:role_id, :is_added, :is_sponsor, :about_me)
    end

    def admin_id
      request.headers['X-User-ID']
    end
  end
end

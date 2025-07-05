require "ostruct"


module Api
  module V1
    class UserController < ApplicationController
      skip_before_action :authenticate_service_request, only: [ :public_profile ]

      def public_profile
        nickname = params[:nickname].to_s.strip
        account = MinecraftAccount.find_by(nickname: nickname)

        unless account
          render json: { error: "Пользователь с ником #{nickname} не найден" }, status: :not_found and return
        end

        user = User.includes(:role).find_by(id: account.user_id)
        discord = DiscordAccount.find_by(user_id: user.id)

        result = OpenStruct.new(
          user_id: user.id,
          nickname: account.nickname,
          is_added: user.is_added,
          about_me: user.about_me,
          youtube_url: user.youtube_url,
          twitch_url: user.twitch_url,
          tiktok_url: user.tiktok_url,
          youtube_channel_name: user.youtube_channel_name,
          twitch_channel_name: user.twitch_channel_name,
          tiktok_channel_name: user.tiktok_channel_name,
          role_name: user.role&.name,
          role_color: user.role&.color,
          discord_account: discord ? OpenStruct.new(
            user_id: discord.user_id,
            discord_id: discord.discord_id,
            username: discord.username,
            discriminator: discord.discriminator,
            avatar: discord.avatar
          ) : nil,
          minecraft_account: OpenStruct.new(
            nickname: account.nickname
          )
        )

        redis_key = "public_profile:#{nickname}"
        REDIS_CLIENT.setex(redis_key, 3.hours.to_i, result.to_h.to_json)

        render json: result.to_h, status: :ok
      end
    end
  end
end

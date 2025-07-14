ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class AuthServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'auth_service'
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end

  consumer_groups.draw do
    consumer_group :auth_service_group do
      topic :auth_service_get_user do
        consumer UserDataRequestConsumer
      end

      topic :minecraft_registration_requests do
        consumer MinecraftRegistrationConsumer
      end

      topic :user_login_events do
        consumer UserLoginConsumer
      end

      topic :two_factor_requests do
        consumer TwoFactorConsumer
      end

      topic :auth_service_set_about_me do
        consumer SetAboutMeConsumer
      end

      topic :get_user_punishments do
        consumer UserPunishmentsConsumer
      end

      topic :auth_service_youtube_unbind do
        consumer UserYoutubeUnbindConsumer
      end

      topic :auth_service_tiktok_unbind do
        consumer UserTikTokUnbindConsumer
      end

      topic :auth_service_twitch_unbind do
        consumer UserTwitchUnbindConsumer
      end

      topic :update_users_data do
        consumer UserUpdateDataConsumer
      end

      topic :add_punishment do
        consumer AddPunishmentConsumer
      end

      topic :cancel_punishment do
        consumer CancelPunishmentConsumer
      end

      topic :change_password do
        consumer ChangePasswordConsumer
      end

      topic :change_profile_data do
        consumer ChangeProfileDataConsumer
      end

      topic :update_punishment_status do
        consumer UpdatePunishmentStatusConsumer
      end

      topic :delete_player do
        consumer DeletePlayerConsumer
      end

      topic :restore_user do
        consumer RestoreUserConsumer
      end
    end
  end
end

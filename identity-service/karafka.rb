ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class IdentityServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'identity-service'
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
      'socket.keepalive.enable': true,
      'message.send.max.retries': 3,
      'retry.backoff.ms': 1000
    }
    config.concurrency = 2
  end

  # Exactly-once semantics for producer
  Karafka::Producer.setup do |producer_config|
    producer_config.kafka = {
      'acks': 'all',
      'enable.idempotence': true,
      'max.in.flight.requests.per.connection': 5
    }
  end

  consumer_groups.draw do
    consumer_group :identity_service_group do
      topic 'identity.user.logged_in' do
        consumer UserLoginConsumer
      end

      topic 'identity.user.registered' do
        consumer UserRegistrationConsumer
      end

      topic 'identity.punishment.added' do
        consumer AddPunishmentConsumer
      end

      topic 'identity.punishment.cancelled' do
        consumer CancelPunishmentConsumer
      end

      topic 'identity.punishment.status_updated' do
        consumer UpdatePunishmentStatusConsumer
      end

      topic 'identity.user.profile_updated' do
        consumer ChangeProfileDataConsumer
      end

      topic 'identity.user.password_changed' do
        consumer ChangePasswordConsumer
      end

      topic 'identity.user.email_changed' do
        consumer ChangeEmailConsumer
      end

      topic 'identity.user.deleted' do
        consumer DeletePlayerConsumer
      end

      topic 'identity.user.restored' do
        consumer RestoreUserConsumer
      end

      topic 'identity.two_factor.code_sent' do
        consumer TwoFactorConsumer
      end

      topic 'identity.social.unbind.tiktok' do
        consumer UnifiedSocialUnbindConsumer
      end

      topic 'identity.social.unbind.twitch' do
        consumer UnifiedSocialUnbindConsumer
      end

      topic 'identity.social.unbind.youtube' do
        consumer UnifiedSocialUnbindConsumer
      end

      topic 'identity.punishment.appeal.created' do
        consumer UnifiedPunishmentAppealConsumer
      end

      topic 'identity.punishment.appeal.dropped' do
        consumer UnifiedPunishmentAppealConsumer
      end

      topic 'identity.user.data_requested' do
        consumer UserDataRequestConsumer
      end

      topic 'identity.user.punishments_requested' do
        consumer UserPunishmentsConsumer
      end

      topic 'game.player.roles_requested' do
        consumer MinecraftRegistrationConsumer
      end

      topic 'identity.user.data_requested.web' do
        consumer UserDataRequestConsumer
      end

      topic 'identity.user.punishments_requested.web' do
        consumer UserPunishmentsConsumer
      end

      topic 'portal.user.data_updated' do
        consumer UserUpdateDataConsumer
      end

      topic 'portal.web_events' do
        consumer WebEventsConsumer
      end

      # Email notifications
      topic 'notification.email' do
        consumer EmailNotificationConsumer
      end

      # Punishment notifications
      topic 'identity.punishment.issued' do
        consumer PunishmentNotificationConsumer
      end

      topic 'identity.punishment.resolved' do
        consumer PunishmentNotificationConsumer
      end

      # User sync events
      topic 'identity.user.sync' do
        consumer UserSyncConsumer
      end
    end
  end
end

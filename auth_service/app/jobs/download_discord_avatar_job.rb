require 'open-uri'


class DownloadDiscordAvatarJob < ApplicationJob
  queue_as :default

  def perform(discord_avatar_id, avatar_url)
    return if discord_avatar_id.blank? || avatar_url.blank?

    discord_avatar = DiscordAvatar.find_by(id: discord_avatar_id)
    unless discord_avatar
      Rails.logger.warn "DiscordAvatar with ID #{discord_avatar_id} not found"
      return
    end

    begin
      # Скачиваем аватарку
      avatar_data = URI.open(avatar_url)

      # Прикрепляем файл
      discord_avatar.file.attach(
        io: avatar_data,
        filename: "avatar_#{discord_avatar.discord_account.discord_id}_#{Time.now.to_i}",
        content_type: avatar_data.content_type
      )

      discord_avatar.save!

      # Формируем абсолютный URL к файлу
      avatar_file_url = Rails.application.routes.url_helpers.rails_blob_url(
        discord_avatar.file,
        host: ENV.fetch('AUTH_SERVICE_URL')
      )

      # Обновляем DiscordAccount
      discord_account = discord_avatar.discord_account
      discord_account.update!(avatar: avatar_file_url)

      Rails.logger.info "Discord avatar updated for account #{discord_account.id}: #{avatar_file_url}"

    rescue OpenURI::HTTPError => e
      Rails.logger.error "Failed to download Discord avatar: #{e.message}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save Discord avatar: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error in DownloadDiscordAvatarJob: #{e.class} - #{e.message}"
    end
  end
end

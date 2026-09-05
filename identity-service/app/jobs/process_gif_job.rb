class ProcessGifJob < ApplicationJob
  queue_as :default

  def perform(discord_avatar_id)
    discord_avatar = DiscordAvatar.find(discord_avatar_id)
    
    # Убедитесь, что attachment существует
    if discord_avatar.file.attached?
      Rails.logger.info "Processing GIF for DiscordAvatar #{discord_avatar.id}"
      GifCropperService.new(discord_avatar.file).process_and_replace
      
      # Перезагружаем запись и проверяем результат
      discord_avatar.reload
      if discord_avatar.file.attached?
        Rails.logger.info "✅ Job completed successfully - attachment is present"
      else
        Rails.logger.error "❌ Job failed - no attachment after processing"
      end
    else
      Rails.logger.error "❌ No file attached to DiscordAvatar #{discord_avatar.id}"
    end
  rescue => e
    Rails.logger.error "💥 ProcessGifJob Error: #{e.message}"
    raise
  end
end

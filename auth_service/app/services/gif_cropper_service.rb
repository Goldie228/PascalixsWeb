require "mini_magick"

class GifCropperService
  def initialize(attachment)
    @attachment = attachment
    @record = attachment.record # Получаем запись, к которой прикреплен файл
  end

  def process_and_replace
    return unless @attachment.attached? && gif?

    input_file = Tempfile.new(['input', '.gif'], binmode: true)
    output_file = Tempfile.new(['output', '.gif'], binmode: true)

    begin
      # Скачиваем attachment
      File.open(input_file.path, 'wb') do |file|
        @attachment.download { |chunk| file.write(chunk) }
      end

      Rails.logger.info "🎬 [GifCropperService] Start processing GIF: #{@attachment.filename}"
      Rails.logger.info "📥 Input file size: #{File.size(input_file.path)} bytes"

      # Получаем размеры до обработки
      before_dimensions = get_dimensions(input_file.path)
      Rails.logger.info "🔍 Before processing: #{before_dimensions}"

      # Обработка с гарантированным квадратным кадрированием
      process_gif_with_system_command(input_file.path, output_file.path)

      # Получаем размеры после обработки
      after_dimensions = get_dimensions(output_file.path)
      Rails.logger.info "🔍 After processing: #{after_dimensions}"
      Rails.logger.info "📊 Output file size: #{File.size(output_file.path)} bytes"

      # Проверяем, что результат не превышает лимиты
      validate_output(output_file.path)

      # Сохраняем оригинальные данные файла
      original_filename = @attachment.filename.to_s

      # Заменяем файл в транзакции
      ActiveRecord::Base.transaction do
        # Удаляем старый attachment
        @attachment.purge
        
        # Создаем новый attachment
        @record.file.attach(
          io: File.open(output_file.path, 'rb'),
          filename: "cropped_#{original_filename}",
          content_type: "image/gif"
        )

        # Сохраняем запись
        if @record.save
          Rails.logger.info "💾 Record saved successfully"
        else
          Rails.logger.error "❌ Failed to save record: #{@record.errors.full_messages}"
          raise ActiveRecord::Rollback
        end
      end

      # Проверяем, что attachment действительно прикрепился
      if @record.file.attached?
        Rails.logger.info "✅ [GifCropperService] GIF successfully processed and replaced!"
        Rails.logger.info "📏 Original: #{before_dimensions} → New: #{after_dimensions}"
        Rails.logger.info "🔗 New attachment: #{@record.file.blob.filename}"
      else
        Rails.logger.error "❌ Attachment failed to attach after processing"
        raise "Attachment failed to attach"
      end

    rescue => e
      Rails.logger.error "💥 [GifCropperService] Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    ensure
      input_file.close! if input_file
      output_file.close! if output_file
    end
  end

  private

  def process_gif_with_system_command(input_path, output_path)
    # Используем ImageMagick convert команду напрямую
    command = [
      "convert",
      input_path,
      "-coalesce",          # Правильно обрабатываем анимированные GIF
      "-resize", "512x512^", # Ресайзим с заполнением до 512x512
      "-gravity", "center",  # Центрируем для кадрирования
      "-extent", "512x512",  # Кадрируем до точного размера
      "-background", "none", # Прозрачный фон
      "-layers", "optimize", # Оптимизируем GIF
      output_path
    ]

    Rails.logger.info "🔧 Executing: #{command.join(' ')}"
    
    success = system(*command)
    
    unless success && File.exist?(output_path)
      raise "Failed to process GIF with ImageMagick. Command: #{command.join(' ')}"
    end

    # Проверяем, что выходной файл создан
    unless File.exist?(output_path) && File.size(output_path) > 0
      raise "Output file was not created or is empty"
    end
  end

  def validate_output(output_path)
    return unless File.exist?(output_path)
    
    image = MiniMagick::Image.open(output_path)
    
    # Проверяем конечные размеры
    if image.width != 512 || image.height != 512
      raise "Output dimensions invalid: #{image.width}x#{image.height}, expected 512x512"
    end
    
    # Проверяем размер файла
    file_size = File.size(output_path)
    if file_size > 10.megabytes
      Rails.logger.warn "⚠️ Output file is large: #{file_size} bytes"
    end
    
    image.destroy!
  rescue => e
    Rails.logger.error "❌ Output validation failed: #{e.message}"
    raise
  end

  def get_dimensions(path)
    return "File not found" unless File.exist?(path)
    
    image = MiniMagick::Image.open(path)
    dimensions = "#{image.width}x#{image.height}"
    image.destroy!
    dimensions
  rescue => e
    "Error: #{e.message}"
  end

  def gif?
    @attachment.content_type == "image/gif"
  end
end

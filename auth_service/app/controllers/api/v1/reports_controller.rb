class Api::V1::ReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [
    :revoke, :update, :add_report, :show, :admin_revoke, :delete, :admin_show
  ]

  skip_before_action :authenticate_service_request, only: [ 
    :add_report, :show, :admin_revoke, :delete, :admin_show
  ]

  # Получение данных жалобы
  def show
    begin
      @report = UserReport.find_by(reported_user_id: params[:id])

      if @report.nil? || !@report.is_active
        active_reports_count = UserReport.where(reporter_id: params['reporter_id'], is_active: true).count

        if active_reports_count >= 3
          return render json: {
            error: "Превышено допустимое количество активных жалоб. Пожалуйста, дождитесь обработки."
          }, status: :forbidden
        end

        return render json: { error: "Жалоба не найдена" }, status: :not_found
      end

      attachments = @report.attachments.map do |attachment|
        report_attachment = @report.report_attachments.find_by(
          filename: attachment.filename.to_s
        )

        {
          id: report_attachment&.id,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type,
          file_size: attachment.byte_size,
          url: "#{ENV['AUTH_SERVICE_URL']}#{Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)}"
        }
      end

      render json: {
        id: @report.id,
        title: @report.title,
        description: @report.description,
        reporter_id: @report.reporter_id,
        reported_user_id: @report.reported_user_id,
        is_active: @report.is_active,
        created_at: @report.created_at,
        updated_at: @report.updated_at,
        attachments: attachments
      }
    rescue => e
      Rails.logger.error("Ошибка при получении жалобы (ID #{params[:id]}): #{e.message}")
      render json: { error: "Не удалось загрузить жалобу. Попробуйте позже." }, status: :internal_server_error
    end
  end

  def admin_show
    begin
      @report = UserReport.find_by(id: params[:id])

      attachments = @report.attachments.map do |attachment|
        report_attachment = @report.report_attachments.find_by(
          filename: attachment.filename.to_s
        )

        {
          id: report_attachment&.id,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type,
          file_size: attachment.byte_size,
          url: "#{ENV['AUTH_SERVICE_URL']}#{Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)}"
        }
      end

      render json: {
        id: @report.id,
        title: @report.title,
        description: @report.description,
        reporter_id: @report.reporter_id,
        reported_user_id: @report.reported_user_id,
        is_active: @report.is_active,
        created_at: @report.created_at,
        updated_at: @report.updated_at,
        attachments: attachments
      }
    rescue => e
      Rails.logger.error("Ошибка при получении жалобы (ID #{params[:id]}): #{e.message}")
      render json: { error: "Не удалось загрузить жалобу. Попробуйте позже." }, status: :internal_server_error
    end
  end

  # Получение списка жалоб для админки
  def index
    begin
      # Параметры по умолчанию
      search_param = params[:search].to_s.strip.downcase
      allowed_sorts = %w[sender recipient title status]
      sort_key = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'sender'
      order_dir = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'
      page = (params[:page] || 1).to_i.clamp(1, 10_000)
      per_page = (params[:per_page] || 25).to_i.clamp(1, 100)
      
      # Базовый запрос с предзагрузкой связанных данных
      reports = UserReport.includes(
        reporter: [:minecraft_account, :discord_account],
        reported_user: [:minecraft_account, :discord_account]
      )
      
      # Фильтрация по поиску
      if search_param.present?
        # Получаем ID пользователей, которые соответствуют поиску
        user_ids = User.where(
          "id IN (SELECT user_id FROM minecraft_accounts WHERE LOWER(nickname) LIKE ?) OR 
           id IN (SELECT user_id FROM discord_accounts WHERE LOWER(username) LIKE ?)",
          "%#{search_param}%", "%#{search_param}%"
        ).pluck(:id)

        reports = reports.where(
          "LOWER(title) LIKE ? OR 
           reporter_id IN (?) OR 
           reported_user_id IN (?)",
          "%#{search_param}%", user_ids, user_ids
        )
      end
      
      # Сортировка с использованием Arel.sql для безопасности
      case sort_key
      when 'sender'
        reports = reports.joins(
          Arel.sql("LEFT JOIN minecraft_accounts AS sender_mc ON user_reports.reporter_id = sender_mc.user_id
                   LEFT JOIN discord_accounts AS sender_dc ON user_reports.reporter_id = sender_dc.user_id")
        ).order(
          Arel.sql("COALESCE(sender_mc.nickname, sender_dc.username, user_reports.reporter_id) #{order_dir}")
        )
      when 'recipient'
        reports = reports.joins(
          Arel.sql("LEFT JOIN minecraft_accounts AS recipient_mc ON user_reports.reported_user_id = recipient_mc.user_id
                   LEFT JOIN discord_accounts AS recipient_dc ON user_reports.reported_user_id = recipient_dc.user_id")
        ).order(
          Arel.sql("COALESCE(recipient_mc.nickname, recipient_dc.username, user_reports.reported_user_id) #{order_dir}")
        )
      when 'title'
        reports = reports.order(Arel.sql("title #{order_dir}"))
      when 'status'
        reports = reports.order(Arel.sql("is_active #{order_dir}"))
      else
        reports = reports.order(Arel.sql("created_at #{order_dir}"))
      end
      
      # Пагинация
      total_count = reports.count
      reports = reports.offset((page - 1) * per_page).limit(per_page)
      
      # Формируем ответ
      formatted_reports = reports.map do |report|
        # Получаем имя отправителя
        sender_name = if report.reporter&.minecraft_account&.nickname.present?
                        report.reporter.minecraft_account.nickname
                      elsif report.reporter&.discord_account&.username.present?
                        report.reporter.discord_account.username
                      else
                        "ID: #{report.reporter_id}"
                      end
        
        # Получаем имя получателя
        recipient_name = if report.reported_user&.minecraft_account&.nickname.present?
                           report.reported_user.minecraft_account.nickname
                         elsif report.reported_user&.discord_account&.username.present?
                           report.reported_user.discord_account.username
                         else
                           "ID: #{report.reported_user_id}"
                         end
        
        # Обрезаем заголовок до 80 символов
        title = report.title.length > 80 ? "#{report.title[0..77]}..." : report.title
        
        {
          id: report.id,
          sender: sender_name,
          recipient: recipient_name,
          title: title,
          status: report.is_active ? 'active' : 'inactive',
          reported_user_id: report.reported_user_id  # Добавляем ID пользователя, на которого пожаловались
        }
      end
      
      render json: {
        complaints: formatted_reports,
        total_count: total_count
      }
      
    rescue => e
      Rails.logger.error "Ошибка при получении списка жалоб: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        error: "Произошла ошибка при загрузке данных жалоб", 
        details: e.message 
      }, status: :internal_server_error
    end
  end

  # Отзыв жалобы
  def revoke
    @report = UserReport.find_by(reported_user_id: params[:id])

    if @report.nil?
      render json: { error: "Жалоба не найдена" }, status: :not_found
      return
    end

    @report.update!(is_active: false)
    render json: { message: "Жалоба успешно отозвана" }
  end

  def admin_revoke
    @report = UserReport.find_by(id: params[:id])

    if @report.nil?
      render json: { error: "Жалоба не найдена" }, status: :not_found
      return
    end

    @report.update!(is_active: false)
    render json: { message: "Жалоба успешно отозвана" }
  end

  def delete
    @report = UserReport.find_by(id: params[:id])

    unless @report
      render json: { error: "Жалоба не найдена" }, status: :not_found
      return
    end

    if @report.destroy
      render json: { message: "Жалоба успешно удалена" }, status: :ok
    else
      render json: { error: "Не удалось удалить жалобу", details: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def add_report
    required_params = %i[title description reported_user_id reporter_id]
    unless required_params.all? { |key| params[key].present? }
      render json: { error: "Не все обязательные поля заполнены" }, status: :unprocessable_entity
      return
    end
    
    if params[:reporter_id] == params[:reported_user_id]
      render json: { error: "Пользователь не может пожаловаться на самого себя" }, status: :unprocessable_entity
      return
    end
    
    reporter = User.find_by(id: params[:reporter_id])
    reported_user = User.find_by(id: params[:reported_user_id])
    
    unless reporter && reported_user
      render json: { error: "Один из пользователей не найден" }, status: :not_found
      return
    end

    report = UserReport.where(
      reporter_id: reporter.id,
      reported_user_id: reported_user.id
    ).first

    # Проверка ограничений перед обработкой файлов
    if report
      file_errors = validate_report_files(report, params)
      if file_errors
        render json: { error: file_errors }, status: :unprocessable_entity
        return
      end
    else
      file_errors = validate_new_report_files(params)
      if file_errors
        render json: { error: file_errors }, status: :unprocessable_entity
        return
      end
    end
    
    # Используем транзакцию для обеспечения целостности данных
    is_new_report = report.nil?

    ActiveRecord::Base.transaction do
      if report
        report.update!(
          title: params[:title],
          description: params[:description],
          is_active: true,
          updated_at: Time.current
        )
        handle_report_files_update(report)
      else
        report = UserReport.new(
          reporter: reporter,
          reported_user: reported_user,
          title: params[:title],
          description: params[:description],
          is_active: true
        )
        report.save!
        handle_report_files_create(report)
      end
    end
    
    render json: {
      message: is_new_report ? "Жалоба создана" : "Жалоба обновлена",
      report_id: report.id
    }, status: is_new_report ? :created : :ok
    
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error in add_report: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Произошла ошибка при обработке жалобы" }, status: :internal_server_error
  end

  private

  # Проверка ограничений для существующего отчета
  def validate_report_files(report, params)
    new_files = extract_files_from_params(params) || []
    # Получаем текущие файлы из базы
    current_attachments = report.attachments
    # Используем абсолютные URL для сравнения
    current_urls = current_attachments.map { |a| Rails.application.routes.url_helpers.rails_blob_url(a, host: ENV['AUTH_SERVICE_URL']) }
    # Получаем файлы, которые должны остаться
    keep_urls = if params[:existing_files].present?
      if params[:existing_files].is_a?(Array)
        params[:existing_files]
      elsif params[:existing_files].is_a?(ActionController::Parameters)
        params[:existing_files].values
      else
        []
      end
    else
      []
    end
    # Файлы для удаления = текущие файлы минус те, что должны остаться
    files_to_delete_count = current_urls.size - (current_urls & keep_urls).size
    new_count = keep_urls.size + new_files.size
    # Рассчитываем новый общий размер
    current_size = current_attachments.sum { |a| a.byte_size }
    # Размер удаляемых файлов (оценка)
    avg_file_size = current_urls.size > 0 ? current_size / current_urls.size : 0
    delete_size = files_to_delete_count * avg_file_size
    # Размер новых файлов
    add_size = new_files.sum(&:size) || 0
    new_size = current_size - delete_size + add_size
    if new_count > 12
      "Максимальное количество файлов - 12"
    elsif new_size > 2.gigabytes
      "Общий размер файлов не должен превышать 2 ГБ"
    end
  end

  # Проверка ограничений для нового отчета
  def validate_new_report_files(params)
    new_files = extract_files_from_params(params) || []
    if new_files.size > 12
      "Максимальное количество файлов - 12"
    elsif new_files.sum(&:size) > 2.gigabytes
      "Общий размер файлов не должен превышать 2 ГБ"
    end
  end

  def handle_report_files_update(report)
    # Получаем текущие прикрепления
    current_attachments = report.attachments.to_a
    # Используем абсолютные URL для сравнения
    current_urls = current_attachments.map { |a| Rails.application.routes.url_helpers.rails_blob_url(a, host: ENV['AUTH_SERVICE_URL']) }
    # Получаем URL файлов, которые должны остаться
    keep_urls = if params[:existing_files].present?
      if params[:existing_files].is_a?(Array)
        params[:existing_files]
      elsif params[:existing_files].is_a?(ActionController::Parameters)
        params[:existing_files].values
      else
        []
      end
    else
      []
    end
    
    # Находим прикрепления для удаления (которых нет в keep_urls)
    attachments_to_delete = current_attachments.select do |attachment|
      url = Rails.application.routes.url_helpers.rails_blob_url(attachment, host: ENV['AUTH_SERVICE_URL'])
      !keep_urls.include?(url)
    end
    
    # Удаляем файлы, которые больше не нужны, напрямую без фоновых задач
    if attachments_to_delete.any?
      # Собираем ID вложений и blob для удаления
      attachment_ids = attachments_to_delete.map(&:id)
      blob_ids = attachments_to_delete.map(&:blob_id)
      
      # Удаляем метаданные
      report.report_attachments.where(
        filename: attachments_to_delete.map { |a| a.filename.to_s }
      ).delete_all
      
      # Удаляем вложения
      ActiveStorage::Attachment.where(id: attachment_ids).delete_all
      
      # Удаляем blob, которые не используются другими attachment
      ActiveStorage::Blob.where(id: blob_ids)
        .where.not(id: ActiveStorage::Attachment.where(blob_id: blob_ids).select(:blob_id))
        .delete_all
    end
    
    # Добавляем новые файлы
    if params[:files].present?
      new_files = extract_files_from_params(params)
      new_files.each do |file|
        begin
          # Прикрепляем файл
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: file.original_filename.to_s, # Преобразуем в строку
            content_type: file.content_type
          )
          
          report.attachments.attach(blob)
          
          # Создаем метаданные
          report.report_attachments.create!(
            filename: file.original_filename.to_s, # Преобразуем в строку
            content_type: file.content_type,
            file_size: file.size
          )
        rescue => e
          Rails.logger.error "Error attaching file: #{e.message}"
          # Продолжаем с другими файлами даже если один не удалось обработать
        end
      end
    end
  end

  def handle_report_files_create(report)
    return unless params[:files].present?
    
    extract_files_from_params(params).each do |file|
      begin
        # Прикрепляем файл
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename.to_s, # Преобразуем в строку
          content_type: file.content_type
        )
        
        report.attachments.attach(blob)
        
        # Создаем метаданные
        report.report_attachments.create!(
          filename: file.original_filename.to_s, # Преобразуем в строку
          content_type: file.content_type,
          file_size: file.size
        )
      rescue => e
        Rails.logger.error "Error creating file attachment: #{e.message}"
        # Продолжаем с другими файлами даже если один не удалось обработать
      end
    end
  end

  def extract_files_from_params(params)
    files = []
    if params[:files].present?
      if params[:files].is_a?(Array)
        files = params[:files]
      elsif params[:files].is_a?(ActionController::Parameters)
        files = params[:files].values
      end
    end
    files.select { |file| file.is_a?(ActionDispatch::Http::UploadedFile) }
  end
end

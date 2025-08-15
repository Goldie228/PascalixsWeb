class PurchasesController < ApplicationController
  # GET /purchases - получение списка покупок для текущего пользователя
  def index
    user_id = current_user.id
    
    # Формируем параметры запроса
    query_params = {
      purchaser_user_id: user_id,
      actor_user_id: user_id
    }
    
    # Добавляем фильтры, если они переданы
    query_params[:status] = params[:status] if params[:status].present?
    query_params[:purchase_type] = params[:purchase_type] if params[:purchase_type].present?
    
    # Делаем запрос к API покупок
    response = HTTParty.get(
      "http://#{ENV['HOST']}:3001/api/v1/purchases",
      query: query_params,
      headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
        "Content-Type" => "application/json"
      }
    )
    
    if response.success?
      # Обрабатываем полученные данные
      purchases = response.parsed_response

      render json: purchases
    else
      render json: { errors: ["Не удалось получить данные о покупках"] }, status: :internal_server_error
    end
  end

  # POST /purchases - создание новой покупки
  def create
    # 1) Базовые параметры из формы
    raw = params.require(:purchase).permit(
      :purchase_type, :amount, :currency, :purchaser_user_id, :image,
      receipt: [] # позволяем вложенные файлы purchase[receipt][]
    )

    # 2) Нормализация amount/currency
    amount_str = raw[:amount].to_s.strip
    if (m = amount_str.match(/\A([0-9]+(?:\.[0-9]+)?)\s*([A-Z]{3})?\z/))
      raw[:amount]   = m[1]
      raw[:currency] = m[2] if m[2].present? && raw[:currency].blank?
    end

    raw[:currency] ||= 'USD'
    raw_id = raw[:purchaser_user_id]
    raw[:purchaser_user_id] =
      (raw_id.present? && raw_id.to_s.strip.downcase != 'null') ? raw_id : current_user.id


    # 3) Валидация обязательных полей до запроса
    missing = []
    missing << 'purchase_type' if raw[:purchase_type].blank?
    missing << 'amount' if raw[:amount].blank?
    missing << 'purchaser_user_id' if raw[:purchaser_user_id].blank?

    begin
      require 'bigdecimal'
      BigDecimal(raw[:amount].to_s)
    rescue ArgumentError
      return render json: { errors: ["Некорректная сумма: #{raw[:amount].inspect}"] }, status: :unprocessable_entity
    end

    if missing.any?
      return render json: { errors: ["Отсутствуют обязательные параметры: #{missing.join(', ')}"] }, status: :unprocessable_entity
    end

    # 4) Собираем файлы из разных мест: params[:receipt], purchase[:receipt], purchase[:image]
    files = []
    files += Array(params[:receipt]) if params[:receipt].present?
    files += Array(raw[:receipt])    if raw[:receipt].present?
    files << raw[:image]              if raw[:image].present?
    files.compact!
    files.uniq!

    # 5) Базовая валидация файлов (только изображения, максимум 5 МБ каждый)
    if files.any?
      errors = []

      files.each do |f|
        original_name = (f.respond_to?(:original_filename) && f.original_filename.present?) ? f.original_filename : 'файл'
        content_type  = (f.respond_to?(:content_type) ? f.content_type : nil)
        size_bytes    =
          if f.respond_to?(:size)
            f.size
          elsif f.respond_to?(:tempfile) && f.tempfile.respond_to?(:size)
            f.tempfile.size
          end

        if content_type.blank? || !content_type.start_with?('image/')
          errors << "Неверный тип для #{original_name}: допустимы только изображения (image/*)"
        end

        if size_bytes.present? && size_bytes > 5.megabytes
          errors << "Слишком большой #{original_name}: максимум 5 МБ"
        end
      end

      return render json: { errors: errors }, status: :unprocessable_entity if errors.any?
    end

    # 6) Формируем тело без status (его выставит API = pending)
    purchase_params = {
      purchase_type:      raw[:purchase_type],
      amount:             raw[:amount],
      currency:           raw[:currency],
      purchaser_user_id:  raw[:purchaser_user_id]
    }
    body = { purchase: purchase_params, actor_user_id: current_user.id }

    # 7) Логируем безопасно
    Rails.logger.info "Отправка в API покупок: #{body.merge(receipt: files.any? ? "[#{files.size} files]" : nil).inspect}"

    url = "http://#{ENV['HOST']}:3001/api/v1/purchases"
    auth_headers = { "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}" }

    # 8) JSON по умолчанию, multipart — если есть файлы
    if files.any?
      # Преобразуем в multipart: receipt[0], receipt[1], ...
      multipart_body = {
        'actor_user_id'               => current_user.id,
        'purchase[purchase_type]'     => purchase_params[:purchase_type],
        'purchase[amount]'            => purchase_params[:amount],
        'purchase[currency]'          => purchase_params[:currency],
        'purchase[purchaser_user_id]' => purchase_params[:purchaser_user_id]
      }

      files.each_with_index do |file, i|
        key = "receipt[#{i}]"
        multipart_body[key] = file
      end

      response = HTTParty.post(
        url,
        headers: auth_headers, # Content-Type выставится автоматически (multipart boundary)
        multipart: true,
        body: multipart_body
      )
    else
      response = HTTParty.post(
        url,
        body: body.to_json,
        headers: auth_headers.merge(
          "Content-Type" => "application/json",
          "Accept"       => "application/json"
        )
      )
    end

    Rails.logger.info "Ответ от API покупок: status=#{response.code} body=#{response.body}"

    if response.success?
      render json: response.parsed_response, status: :created
    else
      errors = Array(response.parsed_response.is_a?(Hash) ? response.parsed_response["errors"] : nil).presence ||
               ["Не удалось создать покупку"]
      render json: { errors: errors }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "Ошибка при создании покупки: #{e.class}: #{e.message}"
    render json: { errors: [e.message] }, status: :internal_server_error
  end
  
  # GET /purchases/:id - получение информации о конкретной покупке
  def show
    purchase_id = params[:id]
    
    response = HTTParty.get(
      "http://#{ENV['HOST']}:3001/api/v1/purchases/#{purchase_id}",
      query: {
        actor_user_id: current_user.id
      },
      headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
        "Content-Type" => "application/json"
      }
    )
    
    if response.success?
      purchase_data = response.parsed_response
      render json: purchase_data
    else
      render json: { errors: ["Покупка не найдена"] }, status: :not_found
    end
  end
  
  # PATCH/PUT /purchases/:id - обновление покупки (например, изменение статуса)
  def update
    purchase_id = params[:id]
    
    # Подготавливаем параметры для обновления
    update_params = {}
    update_params[:status] = params[:status] if params[:status].present?
    
    # Добавляем другие параметры при необходимости
    if params[:amount].present?
      update_params[:amount] = params[:amount]
    end
    
    # Формируем тело запроса
    body = {
      purchase: update_params,
      actor_user_id: current_user.id
    }
    
    # Добавляем файлы чеков, если они есть
    if params[:receipt].present?
      body[:receipt] = params[:receipt]
    end
    
    # Добавляем чеки для удаления, если они есть
    if params[:receipt_to_purge].present?
      body[:receipt_to_purge] = params[:receipt_to_purge]
    end
    
    response = HTTParty.patch(
      "http://#{ENV['HOST']}:3001/api/v1/purchases/#{purchase_id}",
      body: body,
      headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
        "Content-Type" => "application/json"
      }
    )
    
    if response.success?
      purchase_data = response.parsed_response
      render json: purchase_data
    else
      errors = response.parsed_response["errors"] || ["Не удалось обновить покупку"]
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /purchases/:id - удаление покупки
  def destroy
    purchase_id = params[:id]
    
    response = HTTParty.delete(
      "http://#{ENV['HOST']}:3001/api/v1/purchases/#{purchase_id}",
      query: {
        actor_user_id: current_user.id
      },
      headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
        "Content-Type" => "application/json"
      }
    )
    
    if response.success?
      head :no_content
    else
      errors = response.parsed_response["errors"] || ["Не удалось удалить покупку"]
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end
end

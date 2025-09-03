module Api
  module V1
    class PurchasesController < ApplicationController
      before_action :set_actor!                 # актор запроса из БД
      before_action :set_purchase, only: %i[show update destroy]
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_service_request, only: [ :admin_index, :reject, :accept ]

      # GET /api/v1/purchases
      # Фильтры: purchase_type, status, purchaser_user_id (только админ), target_user_id, from, to
      def index
        cleanup_orphan_attachments

        purchases = apply_filters(
          base_scope.with_attached_receipt
        ).recent
        purchases = paginate(purchases)
        render json: purchases.map { |p| serialize_purchase(p) }
      end

      def admin_index
        # Проверяем права администратора
        return render json: { errors: ["Доступно только администраторам"] }, status: :forbidden unless admin?
        # Базовый запрос с joins для получения данных пользователя
        base_query = base_scope.with_attached_receipt
        # Применяем фильтрацию
        filtered_query = apply_admin_filters(base_query)
        
        # Получаем общее количество записей ДО пагинации
        total_count = filtered_query.count
        
        # Применяем сортировку
        sorted_query = apply_admin_sorting(filtered_query)
        
        # Применяем пагинацию
        paginated_query = paginate(sorted_query)
        
        # Выбираем нужные поля
        purchases = paginated_query.select('purchases.*, 
                   minecraft_accounts.nickname as purchaser_minecraft_nickname,
                   minecraft_accounts.id as purchaser_minecraft_uuid')
        # Сериализуем данные
        render json: {
          purchases: purchases.map { |p| serialize_admin_purchase(p) },
          pagination: {
            page: @page,
            per: @per,
            total: total_count
          }
        }
      end

      # POST /api/v1/purchases
      # Файлы — в params[:receipt] или params[:purchase][:receipt] (берём первый)
      def create
        purchase = nil
        prototype = Purchase.new(create_params)
        prototype.id ||= SecureRandom.uuid
        ActiveRecord::Base.transaction do
          validate_related_records!(prototype)
          purchase = find_or_reuse_active_purchase(prototype)
          validate_price!(purchase)
          create_params.except(:id).each do |attr, value|
            purchase.public_send("#{attr}=", value)
          end
          purchase.save!
          attach_receipt!(purchase, params)
        end
        render json: serialize_purchase(purchase), status: :created
      rescue ActiveRecord::RecordInvalid
        render json: { errors: purchase.errors.full_messages }, status: :unprocessable_entity
      rescue ActionController::ParameterMissing => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      # PATCH/PUT /api/v1/purchases/:id
      # Нельзя менять purchase_type. Статус — только админам.
      # Можно заменить чек (receipt) и удалить старый через receipt_to_purge (signed_id).
      def update
        @purchase = Purchase.find(params[:id])
        if params.dig(:purchase, :purchase_type).present?
          return render json: { errors: ["purchase_type нельзя менять"] },
                        status: :unprocessable_entity
        end
        changes = update_params
        if changes.key?(:status)
          return render json: { errors: ["смена статуса доступна только администратору"] },
                        status: :forbidden
        end
        ActiveRecord::Base.transaction do
          @purchase.assign_attributes(changes)
          validate_price!(@purchase)
          validate_related_records!(@purchase)
          @purchase.save!
          purge_receipt!(@purchase, params)
          attach_receipt!(@purchase, params)
        end
        render json: serialize_purchase(@purchase)
      rescue ActiveRecord::RecordInvalid
        render json: { errors: @purchase.errors.full_messages },
               status: :unprocessable_entity
      end

      # DELETE /api/v1/purchases/:id
      # Разрешено владельцу или админу, только для pending/rejected
      def destroy
        unless @purchase.status_pending? || @purchase.status_rejected?
          return render json: { errors: ["Удалить можно только pending/rejected"] }, status: :unprocessable_entity
        end
        unless actor_owns_purchase?(@actor, @purchase)
          return render json: { errors: ["недостаточно прав"] }, status: :forbidden
        end
        @purchase.destroy!
        head :no_content
      end

      def accept
        _, purchase = find_admin_and_pending_purchase(request, params)

        return unless purchase
        case purchase.purchase_type
        when "pass_purchase"
          return render_error("не удалось выдать пропуск", :unprocessable_entity) unless get_pass_purchase(purchase.purchaser_user_id)
        when "pass_gift"
          return render_error("не удалось выдать пропуск", :unprocessable_entity) unless get_pass_purchase(purchase.target_user_id)
        when "sponsor"
          return render_error("не удалось выдать спонсорство", :unprocessable_entity) unless get_sponsor(purchase.purchaser_user_id)
        when "unban"
          return render_error("не удалось снять бан", :unprocessable_entity) unless clear_punishments(purchase.purchaser_user_id, "ban")
        when "unmute"
          return render_error("не удалось снять мут", :unprocessable_entity) unless clear_punishments(purchase.purchaser_user_id, "mute")
        else
          return render_error("товар отсутствует", :unprocessable_entity)
        end
        approve_purchase(purchase)
        render json: { status: "success", message: "Чек одобрен" }, status: :ok
      end

      def reject
        _, purchase = find_admin_and_pending_purchase(request, params)

        return unless purchase
        purchase.status = "rejected"
        if purchase.save
          render json: { status: "success", message: "Чек отклонён" }, status: :ok
        else
          render_error("не удалось отклонить чек", :internal_server_error)
        end
      end

      private

      def render_error(message, status = :unprocessable_entity)
        render json: { error: message }, status: status
      end

      def approve_purchase(purchase)
        return false unless purchase.is_a?(Purchase)
        purchase.status = "approved"
        purchase.save
      end

      # Выдача проходки
      def get_pass_purchase(target_user_id)
        return false if target_user_id.blank?
        user = User.find_by(id: target_user_id)
        return false if user.blank?
        mc_data = user.minecraft_account_data
        return false if mc_data.blank?
        user.role_id = 2
        user.is_added = true
        return false unless user.save
        payload = { nickname: mc_data["nickname"], pass: true, password: mc_data["password"] }
        produce_with_retries("change_pass_status", payload.to_json)
        true
      end

      # Выдача статуса спонсора
      def get_sponsor(target_user_id)
        return false if target_user_id.blank?
        user = User.find_by(id: target_user_id)
        return false if user.blank?
        return false if user.is_sponsor.nil?
        user.is_sponsor = true
        user.save
      end

      # Универсальный метод для снятия наказаний
      def clear_punishments(target_user_id, type)
        return false if target_user_id.blank?
        user = User.find_by(id: target_user_id)
        return false unless user
        mc_data = user.minecraft_account_data
        return false unless mc_data
        punishments, status = PunishmentHistoryService.call(mc_data["nickname"])
        return false unless status == :ok
        active_punishments = punishments.select do |p|
          p[:type].to_s.downcase == type && punishment_active?(p)
        end
        return false if active_punishments.empty?
        ActiveRecord::Base.transaction do
          active_punishments.each do |p|
            punishment_record = UsersPunishment.find_by(id: p[:id])
            next unless punishment_record
            punishment_record.update!(active: false)
          end
        end
        true
      rescue
        false
      end

      def find_admin_and_pending_purchase(request, params)
        user_id = request.headers["X-User-Id"] || params[:user_id]
        return render_error("user_id обязателен", :unauthorized) if user_id.blank?

        user = User.find_by(id: user_id)
        return render_error("пользователь не найден", :not_found) unless user
        return render_error("доступ запрещен", :forbidden) unless [ 3, 4 ].include? user.role_id

        purchase_id = params[:purchase_id]
        return render_error("purchase_id обязателен", :unprocessable_entity) if purchase_id.blank?

        purchase = Purchase.find_by(id: purchase_id)
        return render_error("чек не найден", :not_found) unless purchase
        return render_error("чек одобрен", :unprocessable_entity) if purchase.status == "approved"

        [ user, purchase ]
      end

      def admin?
        [ 3, 4 ].include? @actor.role_id
      end

      # ------- "Актор" из БД (вместо current_user) -------
      # Передавай actor_user_id в заголовке X-Actor-Id или параметром ?actor_user_id=
      def set_actor!
        actor_id = request.headers["X-Actor-Id"].presence || params[:actor_user_id].presence
        return render json: { errors: ["actor_user_id обязателен"] }, status: :unauthorized if actor_id.blank?
        @actor = User.find_by(id: actor_id)
        render json: { errors: ["пользователь-актер не найден"] }, status: :unauthorized if @actor.nil?
      end

      def actor_owns_purchase?(actor, purchase)
        purchase.purchaser_user_id == actor.id || purchase.target_user_id == actor.id
      end

      # ------- Видимость -------
      def base_scope
        Purchase
          .joins('LEFT JOIN users ON users.id = purchases.purchaser_user_id')
          .joins('LEFT JOIN minecraft_accounts ON minecraft_accounts.user_id = users.id')
      end

      def set_purchase
        @purchase = base_scope.with_attached_receipt.find(params[:id])
      end

      # ------- Фильтры и пагинация -------
      def apply_filters(scope)
        scope = scope.where(purchase_type: params[:purchase_type]) if params[:purchase_type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        
        # Добавляем фильтрацию по purchaser_user_id и target_user_id
        scope = scope.where(purchaser_user_id: params[:purchaser_user_id]) if params[:purchaser_user_id].present?
        scope = scope.where(target_user_id: params[:target_user_id]) if params[:target_user_id].present?
        if params[:from].present?
          scope = scope.where("created_at >= ?", time_parse(params[:from]))
        end
        if params[:to].present?
          scope = scope.where("created_at <= ?", time_parse(params[:to]))
        end
        scope
      end

      def paginate(scope)
        @page = params[:page].to_i.positive? ? params[:page].to_i : 1
        @per  = params[:per].to_i.positive? ? [ params[:per].to_i, 100 ].min : 25
        scope.offset((@page - 1) * @per).limit(@per)
      end

      def time_parse(value)
        Time.zone ? Time.zone.parse(value) : Time.parse(value)
      end

      def validate_price!(purchase)
        price = purchase.amount.to_f
        type  = purchase.purchase_type.to_s.downcase
        unless price.positive?
          purchase.errors.add(:amount, 'должна быть положительной')
          raise ActiveRecord::RecordInvalid, purchase
        end
        user = User.find_by(id: purchase.purchaser_user_id)
        if user.nil?
          purchase.errors.add(:purchaser_user_id, 'не существует')
          raise ActiveRecord::RecordInvalid, purchase
        end
        if type == "unban" || type == "unmute"
          expected_price = calculate_punishment_price(user, type)
          if expected_price != price
            purchase.errors.add(:amount, "Ожидалась цена #{expected_price}, но получено #{price}")
          end
        else
          product = Product.find_by(product_type: type)
          if product.nil?
            purchase.errors.add(:base, "Товар #{type} не найден")
          elsif product.price != price
            purchase.errors.add(:amount, "Ожидалась цена #{product.price}, но получено #{price}")
          end
        end
        raise ActiveRecord::RecordInvalid, purchase if purchase.errors.any?
      end

      def calculate_punishment_price(user, type)
        return { total_price: 0, punishments: [] } unless user&.minecraft_account_data["nickname"].present?
        # Забираем все наказания пользователя
        punishments, status = PunishmentHistoryService.call(user.minecraft_account_data["nickname"])
        # Фильтруем по типу и активности
        active_punishments = punishments.select do |p|
          p[:type].to_s.downcase == type.downcase && punishment_active?(p)
        end
        # Суммируем цену
        total_price = active_punishments.sum { |p| p[:price].to_f }
        {
          total_price: total_price,
          punishments: active_punishments.map do |p|
            {
              uuid:   p[:id],
              reason: p[:reason],
              price:  p[:price]
            }
          end
        }
      end

      def punishment_active?(p)
        return false unless p[:issued_at_raw].present?
        return false if p[:status].present? && p[:status] == I18n.t('admin.players.punishments.status.expired')
        expires = begin
                    Time.parse(p[:expires_at]) unless p[:expires_at] == "—"
                  rescue
                    nil
                  end
        expires.nil? || Time.current < expires
      end

      # ------- Strong params с учетом типа -------
      def type_from_params
        (params.dig(:purchase, :purchase_type) || params[:purchase_type]).presence
      end

      def create_params
        type = type_from_params&.to_s
        raise ActionController::ParameterMissing, "purchase[purchase_type]" if type.blank?
        common = %i[id purchaser_user_id amount currency metadata]
        with_target = %i[target_user_id]
        with_punish = %i[punishment_id]
        allowed = case type
                  when "pass_purchase", "sponsor", "donation"
                    common
                  when "pass_gift"
                    common + with_target
                  when "unban", "unmute"
                    common + with_target + with_punish
                  else
                    common
                  end
        params.require(:purchase).permit(*(allowed + [:purchase_type]), metadata: {})
      end

      def update_params
        type = @purchase.purchase_type
        common = %i[amount currency metadata]
        with_target = %i[target_user_id]
        with_punish = %i[punishment_id]
        allowed = case type
                  when "pass_purchase", "sponsor", "donation"
                    common
                  when "pass_gift"
                    common + with_target
                  when "unban", "unmute"
                    common + with_target + with_punish
                  else
                    common
                  end
        return {} unless params[:purchase].is_a?(ActionController::Parameters)
        params.require(:purchase).permit(*allowed, metadata: {})
      end

      def find_or_reuse_active_purchase(proto)
        # Статусы, в которых запрещаем дубликаты и переиспользуем запись
        restricted_statuses = %w[pending rejected refunded]
        return proto unless restricted_statuses.include?(proto.status)
        Purchase.lock.where(
          purchase_type:     proto.purchase_type,
          status:            proto.status,
          purchaser_user_id: proto.purchaser_user_id,
          target_user_id:    proto.target_user_id
        ).first || proto
      end

      # ------- Дополнительные проверки связей -------
      def validate_related_records!(purchase)
        # Проверка purchaser
        unless User.exists?(id: purchase.purchaser_user_id)
          purchase.errors.add(:purchaser_user_id, 'не существует')
        end
        # Проверка target
        if purchase.target_user_id.present? && !User.exists?(id: purchase.target_user_id)
          purchase.errors.add(:target_user_id, 'не существует')
        end
        # Проверка punishment для unban/unmute
        if (purchase.type_unban? || purchase.type_unmute?) && purchase.punishment_id.present?
          pun = UsersPunishment.find_by(id: purchase.punishment_id)
          if pun.nil?
            purchase.errors.add(:punishment_id, 'не найден')
          elsif purchase.target_user_id.present? && pun.bad_user_id != purchase.target_user_id
            purchase.errors.add(:punishment_id, 'не относится к target_user_id')
          end
        end
        # Если есть ошибки — выбросим как валидацию
        raise ActiveRecord::RecordInvalid, purchase if purchase.errors.any?
      end

      # ------- Файлы -------
      def attach_receipt!(purchase, params)
        raw_files = []
        # ------- Верхний уровень -------
        if params[:receipt].present?
          if params[:receipt].is_a?(ActionDispatch::Http::UploadedFile)
            raw_files << params[:receipt]
          elsif params[:receipt].is_a?(Hash) || params[:receipt].is_a?(ActionController::Parameters)
            raw_files.concat(params[:receipt].values)
          end
        end
        # ------- Вложенный в purchase -------
        if params.dig(:purchase, :receipt).present?
          inner = params[:purchase][:receipt]
          if inner.is_a?(ActionDispatch::Http::UploadedFile)
            raw_files << inner
          elsif inner.is_a?(Hash) || inner.is_a?(ActionController::Parameters)
            raw_files.concat(inner.values)
          end
        end
        # Оставляем только загруженные файлы
        files = raw_files.compact.select { |f| f.respond_to?(:tempfile) }
        return if files.empty?
        # has_one_attached: прикрепляем только первый файл
        purchase.with_lock do
          purchase.receipt.attach(files.first)
        end
      end

      def cleanup_orphan_attachments
        ActiveStorage::Attachment
          .left_joins(:blob)
          .where(active_storage_blobs: { id: nil })
          .find_each(&:destroy)
      end

      def purge_receipt!(purchase, params_source)
        ids = Array(params_source[:receipt_to_purge]) +
              Array(params_source.dig(:purchase, :receipt_to_purge))
        ids = ids.compact.uniq
        return if ids.empty?
        purchase.with_lock do
          existing_ids = purchase.receipt.blobs.where(signed_id: ids).pluck(:id)
          purchase.receipt.where(blob_id: existing_ids).each(&:purge_later)
        end
      end

      # ------- Сериализация -------
      def serialize_purchase(p)
        host = ENV["AUTH_SERVICE_URL"] || request.base_url
        {
          id: p.id,
          purchase_type: p.purchase_type,
          status: p.status,
          amount: p.amount,
          currency: p.currency,
          purchaser_user_id: p.purchaser_user_id,
          target_user_id: p.target_user_id,
          target_user_nickname: User.find_by(id: p.target_user_id)&.minecraft_account_data&.[]("nickname") || '',
          punishment_id: p.punishment_id,
          metadata: p.metadata.presence || {},
          receipt: (if p.receipt.attached?
            blob = p.receipt.blob
            {
              url: rails_blob_url(p.receipt, host: host),
              filename: blob.filename.to_s,
              content_type: blob.content_type,
              byte_size: blob.byte_size,
              signed_id: blob.signed_id,
              checksum: blob.checksum
            }
          end),
          created_at: p.created_at,
          updated_at: p.updated_at
        }
      end

      # ------- Ошибки -------
      def render_not_found
        render json: { errors: ["Покупка не найдена"] }, status: :not_found
      end

      # ------- Админка -------    
      def apply_admin_filters(scope)
        # Фильтрация по типу покупки
        scope = scope.where(purchase_type: params[:purchase_type]) if params[:purchase_type].present?
        
        # Фильтрация по статусу
        scope = scope.where(status: params[:status]) if params[:status].present?
        
        # Фильтрация по ID покупателя
        scope = scope.where(purchaser_user_id: params[:purchaser_user_id]) if params[:purchaser_user_id].present?
        
        # Фильтрация по ID целевого пользователя
        scope = scope.where(target_user_id: params[:target_user_id]) if params[:target_user_id].present?
        
        # Фильтрация по диапазону дат
        if params[:from].present?
          scope = scope.where("purchases.created_at >= ?", time_parse(params[:from]))
        end
        
        if params[:to].present?
          scope = scope.where("purchases.created_at <= ?", time_parse(params[:to]))
        end
        
        # Фильтрация по minecraft никнейму (исправлено для SQLite)
        if params[:purchaser_nickname].present?
          scope = scope.where("minecraft_accounts.nickname LIKE ? COLLATE NOCASE", "%#{params[:purchaser_nickname]}%")
        end
        scope
      end

      def apply_admin_sorting(scope)
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'
        
        # Разрешенные поля для сортировки
        allowed_sort_fields = {
          'id' => 'purchases.id',
          'purchaser_user_id' => 'purchases.purchaser_user_id',
          'purchase_type' => 'purchases.purchase_type',
          'status' => 'purchases.status',
          'amount' => 'purchases.amount',
          'created_at' => 'purchases.created_at',
          'purchaser_nickname' => 'minecraft_accounts.nickname'
        }
        
        sort_field = allowed_sort_fields[sort_by] || 'purchases.created_at'
        sort_direction = %w[asc desc].include?(sort_order) ? sort_order : 'desc'
        
        scope.order("#{sort_field} #{sort_direction}")
      end

      def serialize_admin_purchase(p)
        {
          id: p.id,
          purchaser_user_id: p.purchaser_user_id,
          purchaser_minecraft_nickname: p.purchaser_minecraft_nickname,
          purchaser_minecraft_uuid: p.purchaser_minecraft_uuid,
          purchase_type: p.purchase_type,
          status: p.status,
          amount: p.amount.to_f,
          currency: p.currency,
          target_user_id: p.target_user_id,
          created_at: p.created_at,
          updated_at: p.updated_at
        }
      end
    end
  end
end

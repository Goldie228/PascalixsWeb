module Api
  module V1
    class PurchasesController < ApplicationController
      before_action :set_actor!                 # актор запроса из БД
      before_action :set_purchase, only: %i[show update destroy]
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      skip_before_action :verify_authenticity_token

      # GET /api/v1/purchases
      # Фильтры: purchase_type, status, purchaser_user_id (только админ), target_user_id (только админ), from, to
      def index
        cleanup_orphan_attachments

        purchases = apply_filters(
          base_scope.with_attached_receipt
        ).recent

        Rails.logger.info "[purchases#index] after filters count=#{purchases.size}"

        purchases.each do |p|
          Rails.logger.info "[purchases#index] purchase_id=#{p.id} attached?=#{p.receipt.attached?} filename=#{p.receipt.blob&.filename}"
        end

        purchases = paginate(purchases)
        Rails.logger.info "[purchases#index] after pagination count=#{purchases.size}"

        serialized = purchases.map { |p| serialize_purchase(p) }
        Rails.logger.info "[purchases#index] serialized sample=#{serialized.first.inspect}"

        render json: serialized
      end

      # GET /api/v1/purchases/:id
      def show
        render json: serialize_purchase(@purchase)
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

        if changes.key?(:status) && !admin?
          return render json: { errors: ["смена статуса доступна только администратору"] },
                        status: :forbidden
        end

        ActiveRecord::Base.transaction do
          @purchase.assign_attributes(changes)
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

        unless admin? || actor_owns_purchase?(@actor, @purchase)
          return render json: { errors: ["недостаточно прав"] }, status: :forbidden
        end

        @purchase.destroy!
        head :no_content
      end

      private

      # ------- "Актор" из БД (вместо current_user) -------
      # Передавай actor_user_id в заголовке X-Actor-Id или параметром ?actor_user_id=
      def set_actor!
        actor_id = request.headers["X-Actor-Id"].presence || params[:actor_user_id].presence
        return render json: { errors: ["actor_user_id обязателен"] }, status: :unauthorized if actor_id.blank?

        @actor = User.find_by(id: actor_id)
        return render json: { errors: ["пользователь-актер не найден"] }, status: :unauthorized if @actor.nil?
      end

      def admin?
        [3, 4].include?(@actor.role_id)
      end

      def actor_owns_purchase?(actor, purchase)
        purchase.purchaser_user_id == actor.id || purchase.target_user_id == actor.id
      end

      # ------- Видимость -------
      def base_scope
        return Purchase.all if admin?

        Purchase.where(
          Purchase.arel_table[:purchaser_user_id].eq(@actor.id)
          .or(Purchase.arel_table[:target_user_id].eq(@actor.id))
        )
      end

      def set_purchase
        @purchase = base_scope.with_attached_receipt.find(params[:id])
      end

      # ------- Фильтры и пагинация -------
      def apply_filters(scope)
        scope = scope.where(purchase_type: params[:purchase_type]) if params[:purchase_type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?

        if admin?
          scope = scope.where(purchaser_user_id: params[:purchaser_user_id]) if params[:purchaser_user_id].present?
          scope = scope.where(target_user_id: params[:target_user_id]) if params[:target_user_id].present?
        end

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
        @per  = params[:per].to_i.positive? ? [params[:per].to_i, 100].min : 25
        scope.offset((@page - 1) * @per).limit(@per)
      end

      def time_parse(value)
        Time.zone ? Time.zone.parse(value) : Time.parse(value)
      end

      # ------- Strong params с учетом типа -------
      def type_from_params
        (params.dig(:purchase, :purchase_type) || params[:purchase_type]).presence
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
          punishment_id: p.punishment_id,
          metadata: p.metadata.presence || {},
          receipt: p.receipt.map do |att|
            next unless att.blob
            {
              url: rails_blob_url(att, host: host),
              filename: att.blob.filename.to_s,
              content_type: att.blob.content_type,
              byte_size: att.blob.byte_size,
              signed_id: att.blob.signed_id,
              checksum: att.blob.checksum
            }
          end.compact,
          created_at: p.created_at,
          updated_at: p.updated_at
        }
      end

      def create_params
        type = type_from_params&.to_s
        raise ActionController::ParameterMissing, "purchase[purchase_type]" if type.blank?

        common = %i[id purchaser_user_id amount currency metadata]
        admin_only = %i[status]
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

        allowed += admin_only if admin?

        params.require(:purchase).permit(*(allowed + [:purchase_type]), metadata: {})
      end

      def update_params
        type = @purchase.purchase_type

        common = %i[amount currency metadata]
        admin_only = %i[status]
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

        allowed += admin_only if admin?

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
    end
  end
end

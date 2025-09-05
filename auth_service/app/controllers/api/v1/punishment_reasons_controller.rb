class Api::V1::PunishmentReasonsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_service_request

  before_action :validate_index_params, only: :index
  before_action :validate_create_params, only: :create
  before_action :validate_update_params, only: :update
  before_action :is_admin?

  def index
    reasons = PunishmentReason.where(punishment_type: params[:type])
                              .order(:rule_number)
                              .select(:rule_number, :description, :price)

    render json: { reasons: reasons.as_json(only: %i[rule_number description price]) }
  end

  def all
    # Базовый запрос
    reasons = PunishmentReason.all

    # Фильтрация по типу наказания (если передан)
    if params[:type].present?
      unless %w[ban mute].include?(params[:type])
        return render json: { error: "Invalid type. Allowed types: ban, mute" }, status: :bad_request
      end
      reasons = reasons.where(punishment_type: params[:type])
    end

    # Поиск по описанию (нечеткий поиск)
    if params[:search].present?
      term = "%#{params[:search]}%"
      reasons = reasons.where("LOWER(description) LIKE LOWER(?)", term)
    end

    # Фильтрация по номеру правила
    if params[:rule_number].present?
      reasons = reasons.where(rule_number: params[:rule_number])
    end

    # Фильтрация по цене (диапазон)
    if params[:min_price].present?
      reasons = reasons.where("price >= ?", params[:min_price])
    end

    if params[:max_price].present?
      reasons = reasons.where("price <= ?", params[:max_price])
    end

    # Сортировка
    sort_field = params[:sort] || :rule_number
    sort_direction = params[:direction] || :asc

    # Проверяем, что поле для сортировки допустимо
    allowed_sort_fields = ['rule_number', 'description', 'price', 'punishment_type', 'created_at']
    if allowed_sort_fields.include?(sort_field.to_s)
      reasons = reasons.order(sort_field => sort_direction)
    else
      reasons = reasons.order(:rule_number)
    end

    # Пагинация
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    reasons = reasons.page(page).per(per_page)

    # Подготовка данных для ответа
    total_count = reasons.total_count
    total_pages = reasons.total_pages

    render json: {
      reasons: reasons.as_json(only: %i[rule_number description price punishment_type created_at]),
      pagination: {
        current_page: page.to_i,
        per_page: per_page.to_i,
        total_count: total_count,
        total_pages: total_pages
      }
    }
  end

  def show
    reason = PunishmentReason.find_by(rule_number: params[:rule_number])

    if reason
      render json: { reason: reason.as_json(only: %i[rule_number description price punishment_type]) }
    else
      render json: { error: "Punishment reason not found" }, status: :not_found
    end
  end

  def create
    reason = PunishmentReason.new(punishment_reason_params)

    if reason.save
      render json: { status: "ok", reason: reason.as_json(only: %i[rule_number description price punishment_type]) }, status: :created
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    reason = PunishmentReason.find_by(
      punishment_type: params[:punishment_type],
      rule_number: params[:rule_number]
    )

    unless reason
      return render json: { error: "Punishment reason not found" }, status: :not_found
    end

    if reason.update(punishment_reason_params)
      render json: { status: "ok", reason: reason.as_json(only: %i[rule_number description price punishment_type]) }
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    reason = PunishmentReason.find_by(rule_number: params[:rule_number])

    unless reason
      return render json: { error: "Punishment reason not found" }, status: :not_found
    end

    if reason.destroy
      render json: { status: "ok", message: "Punishment reason deleted successfully" }
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def is_admin?
    user_id = request.headers["X-User-ID"]

    unless user_id.present?
      render json: { error: "missing X-User-ID header" }, status: :unauthorized
      return false
    end

    user = User.find_by(id: user_id)

    unless user && [3, 4].include?(user.role_id)
      render json: { error: "not admin" }, status: :forbidden
      return false
    end

    true
  end

  def validate_index_params
    unless %w[ban mute].include?(params[:type].to_s)
      render json: { error: "Invalid type. Allowed types: ban, mute" }, status: :bad_request
    end
  end

  def validate_create_params
    if PunishmentReason.exists?(punishment_type: params[:type], rule_number: params[:rule_number])
      render json: { error: "Rule number must be unique within punishment type" }, status: :unprocessable_entity
    end
  end

  def validate_update_params
    unless params.key?(:rule_number)
      render json: { error: "Rule number is required for update" }, status: :bad_request
    end
  end

  def punishment_reason_params
    params.permit(:punishment_type, :rule_number, :description, :price)
  end
end

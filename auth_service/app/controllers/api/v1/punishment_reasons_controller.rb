class Api::V1::PunishmentReasonsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :index ]
  skip_before_action :authenticate_service_request, only: [ :index ]

  def index
    type = params[:type].to_s
    unless %w[ban mute].include?(type)
      return render json: { error: "invalid type" }, status: :bad_request
    end

    reasons = PunishmentReason.where(punishment_type: type)
                              .order(:rule_number)
                              .select(:rule_number, :description, :price)

    render json: { reasons: reasons.as_json(only: %i[rule_number description price]) }
  end
end

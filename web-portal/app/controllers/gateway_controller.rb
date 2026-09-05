class GatewayController < ApplicationController
  skip_before_action :update_current_user, :set_locale, :redirect_to_default_locale, :set_timezone, :transfer_session_flash

  # GET /api/v1/proxy/:service/:path
  # POST/PUT/PATCH/DELETE /api/v1/proxy/:service/:path
  def proxy
    service = params[:service]&.to_sym

    unless GatewayService::SERVICE_URLS.key?(service)
      return render json: { error: "Invalid service", available: GatewayService::SERVICE_URLS.keys }, status: 400
    end

    path    = params[:path]
    method  = request.method.downcase.to_sym

    result = GatewayService.new.proxy(service, method, path, headers: extract_client_headers, body: read_body)

    render json: result[:body], status: result[:status]
  rescue GatewayService::ServiceUnavailable
    render json: { error: "Service unavailable", message: "The requested service could not be reached" }, status: 503
  rescue GatewayService::TimeoutError
    render json: { error: "Service timeout", message: "The requested service timed out" }, status: 504
  rescue GatewayService::GatewayError => e
    render json: { error: "Gateway error", message: e.message }, status: 500
  rescue => e
    Rails.logger.error "Gateway proxy error: #{e.message}"
    render json: { error: "Internal gateway error" }, status: 502
  end

  # GET /api/v1/minecraft/status
  def game_status
    result = GatewayService.new.proxy(:game, :get, "/api/v1/minecraft/status")

    if result[:status] == 200
      render json: result[:body]
    else
      render json: { error: "Failed to fetch game status" }, status: 502
    end
  rescue => e
    Rails.logger.error "Game status error: #{e.message}"
    render json: { error: "Gateway error", message: e.message }, status: 500
  end

  # POST /api/v1/minecraft/sync
  def game_sync
    nickname = params[:nickname]

    unless nickname.present?
      return render json: { error: "Nickname is required" }, status: 400
    end

    result = GatewayService.new.proxy(
      :game,
      :post,
      "/api/v1/minecraft/sync",
      body: { nickname: }.to_json
    )

    if result[:status] == 200
      render json: result[:body]
    else
      render json: { error: "Sync failed", details: result[:body] }, status: 502
    end
  rescue => e
    Rails.logger.error "Game sync error: #{e.message}"
    render json: { error: "Gateway error", message: e.message }, status: 500
  end

  private

  def extract_client_headers
    # Forward relevant client headers, strip hop-by-hop headers
    skip_headers = %w[Host Connection Keep-Alive Transfer-Encoding Proxy-Authorization Te Trail]
    request.headers.to_h.reject { |k,| skip_headers.include?(k) }
  end

  def read_body
    body = request.body.read
    request.body.rewind if request.body.respond_to?(:rewind)
    body
  end
end

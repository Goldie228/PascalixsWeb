class ServiceClient
  class << self
    # Generic method to call any service
    def call(service, method, path, body: nil, headers: {})
      url = "#{ENV.fetch("#{service}_SERVICE_URL") { raise "Missing #{service}_SERVICE_URL env var" }}#{path}"

      response = HTTParty.send(
        method,
        url,
        headers: default_headers.merge(headers),
        body: body&.to_json,
        timeout: 5,
        read_timeout: 5
      )

      {
        status: response.code,
        body: parse_response(response),
        headers: response.headers.to_hash
      }
    end

    # Identity Service clients
    def get_user(user_id)
      call(:identity, :get, "/api/v1/users/#{user_id}")
    end

    def get_player_profile(nickname)
      call(:identity, :get, "/api/v1/players/#{nickname}")
    end

    def authenticate(nickname, password)
      call(:identity, :post, "/api/v1/sessions", body: { nickname:, password: })
    end

    def verify_2fa(user_id, otp)
      call(:identity, :post, "/api/v1/two_factor_authentication/verify", body: { user_id:, otp: })
    end

    def lookup_email(email)
      call(:identity, :get, "/api/v1/lookup_email", headers: { 'X-Email' => email })
    end

    # Game Service clients
    def sync_player(nickname)
      call(:game, :post, "/api/v1/players/#{nickname}/sync")
    end

    def get_player_game_data(nickname)
      call(:game, :get, "/api/v1/players/#{nickname}/game_data")
    end

    # Notification Service clients
    def send_push_notification(user_id, data)
      call(:notification, :post, "/api/v1/notifications/push", body: { user_id:, data: })
    end

    def send_email_notification(user_id, mailer_method, opts = {})
      call(:notification, :post, "/api/v1/notifications/email", body: { user_id:, mailer_method:, **opts })
    end

    private

    def default_headers
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'X-Api-Key' => ENV.fetch('INTER_SERVICE_API_KEY') { raise "Missing INTER_SERVICE_API_KEY env var" }
      }
    end

    def parse_response(response)
      body = response.body
      return {} if body.blank?

      begin
        JSON.parse(body)
      rescue JSON::ParserError
        { raw: body }
      end
    rescue HTTParty::Error => e
      Rails.logger.error "[ServiceClient] HTTP error: #{e.message}"
      { error: e.message, status: response.code }
    rescue => e
      Rails.logger.error "[ServiceClient] Error: #{e.message}"
      { error: e.message }
    end
  end
end

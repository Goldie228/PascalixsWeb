class GatewayService
  SERVICE_URLS = {
    identity:    ENV.fetch("IDENTITY_SERVICE_URL") { "http://identity-service:3001" },
    game:        ENV.fetch("GAME_SERVICE_URL") { "http://game-service:3003" },
    notification: ENV.fetch("NOTIFICATION_SERVICE_URL") { "http://notification-service:3004" }
  }.freeze

  API_KEY = ENV.fetch("INTER_SERVICE_API_KEY") { "" }

  class GatewayError < StandardError; end
  class ServiceUnavailable < GatewayError; end
  class TimeoutError < GatewayError; end

  def initialize(timeout: 5.0, retries: 3)
    @timeout = timeout
    @retries = retries
  end

  def proxy(service, method, path, headers: {}, body: nil)
    url = "#{SERVICE_URLS[service]}#{path}"

    @retries.times do |attempt|
      begin
        response = send_request(method, url, headers:, body:)

        return {
          status:  response.status.to_i,
          body:    parse_body(response),
          headers: response.headers.to_h
        }
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
        raise TimeoutError, "Service #{service} timed out" if attempt == @retries - 1
        sleep(0.1 * (2**attempt)) # exponential backoff
      rescue Faraday::HTTPError, Faraday::ConnectionFailed => e
        raise ServiceUnavailable, "Service #{service} unavailable" if attempt == @retries - 1
        sleep(0.1 * (2**attempt))
      end
    end
  end

  private

  def send_request(method, url, headers:, body:)
    case method.to_sym
    when :get
      HTTParty.get(url, headers: build_headers(headers), timeout: @timeout)
    when :post
      HTTParty.post(url, headers: build_headers(headers), body:, timeout: @timeout)
    when :put
      HTTParty.put(url, headers: build_headers(headers), body:, timeout: @timeout)
    when :patch
      HTTParty.patch(url, headers: build_headers(headers), body:, timeout: @timeout)
    when :delete
      HTTParty.delete(url, headers: build_headers(headers), timeout: @timeout)
    else
      raise GatewayError, "Unsupported HTTP method: #{method}"
    end
  end

  def build_headers(headers)
    headers.merge({
      "Authorization" => "Bearer #{API_KEY}",
      "Content-Type"  => "application/json",
      "Accept"        => "application/json"
    }.compact)
  end

  def parse_body(response)
    body = response.body
    return {} if body.blank?

    begin
      JSON.parse(body)
    rescue JSON::ParserError
      { raw: body }
    end
  end
end

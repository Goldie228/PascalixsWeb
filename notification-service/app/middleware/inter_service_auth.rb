class InterServiceAuth
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    api_key = request.env['HTTP_X_API_KEY']

    # Skip auth for health checks and internal calls from localhost
    path = request.path
    return @app.call(env) if path.start_with?('/health') || internal_request?(request)

    unless api_key && api_key == ENV['INTER_SERVICE_API_KEY']
      return [
        401,
        { 'Content-Type' => 'application/json' },
        [{ error: 'Unauthorized', message: 'Invalid or missing inter-service API key' }.to_json]
      ]
    end

    @app.call(env)
  end

  private

  def internal_request?(request)
    internal_ips = ['127.0.0.1', '::1', 'localhost']
    internal_ips.include?(request.ip)
  end
end

class RateLimitingMiddleware
  # Тарифные планы для rate limiting
  TIERS = {
    auth: {
      requests: 10,
      window: 5.minutes,
      description: 'Authentication endpoints (login, register, 2FA)'
    },
    api: {
      requests: 30,
      window: 1.minute,
      description: 'API endpoints (players, users, punishments)'
    },
    public: {
      requests: 60,
      window: 1.minute,
      description: 'Public endpoints (gallery, reports, etc.)'
    }
  }.freeze

  # Роуты для каждого тарифа
  ROUTE_TIERS = {
    '/api/v1/sessions' => :auth,
    '/api/v1/auth' => :auth,
    '/api/v1/two_factor' => :auth,
    '/api/v1/two_factor_authentication' => :auth,
    '/api/v1/players' => :api,
    '/api/v1/users' => :api,
    '/api/v1/punishments' => :api,
    '/api/v1/reports' => :api,
    '/api/v1/lookup_email' => :api,
    '/api/v1/gallery' => :public,
    '/api/v1/punishment_reasons' => :public,
    '/api/v1/integrations' => :public
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    ip = client_ip(request)
    path = request.path

    # Skip rate limiting for internal service-to-service calls
    return @app.call(env) if internal_request?(request)

    tier = determine_tier(path)
    return @app.call(env) unless tier

    limit_config = TIERS[tier]
    return @app.call(env) unless limit_config

    key = "rate_limit:#{tier}:#{ip}"
    current = REDIS_CLIENT.get(key).to_i

    if current >= limit_config[:requests]
      return rate_limited_response(limit_config[:window])
    end

    # Increment counter
    if current == 0
      REDIS_CLIENT.setex(key, limit_config[:window].to_i, 1)
    else
      REDIS_CLIENT.incr(key)
    end

    # Call the app
    status, headers, body = @app.call(env)

    # Add rate limit headers
    headers['X-RateLimit-Limit'] = limit_config[:requests].to_s
    headers['X-RateLimit-Remaining'] = [limit_config[:requests] - current - 1, 0].max.to_s
    headers['X-RateLimit-Reset'] = (Time.current + limit_config[:window]).to_i.to_s

    [status, headers, body]
  end

  private

  def client_ip(request)
    # Check for forwarded IP (behind reverse proxy)
    forwarded = request.env['HTTP_X_FORWARDED_FOR']
    return forwarded.split(',').first.strip if forwarded.present?

    request.remote_ip
  end

  def internal_request?(request)
    # Skip for service-to-service calls
    internal_ips = ['127.0.0.1', '::1']
    internal_ips.include?(client_ip(request))
  end

  def determine_tier(path)
    ROUTE_TIERS.each do |route, tier|
      return tier if path.start_with?(route)
    end
    :public  # Default tier
  end

  def rate_limited_response(window)
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => window.to_i.to_s,
        'X-RateLimit-Limit' => '0',
        'X-RateLimit-Remaining' => '0'
      },
      [{ error: 'Too many requests. Please try again later.', retry_after: window.to_i }.to_json]
    ]
  end
end

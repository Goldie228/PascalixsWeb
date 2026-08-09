Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      [
        'https://pascalixs.fun',
        'https://auth.pascalixs.fun',
        ENV['WEB_SERVICE_URL'],
        ENV['AUTH_SERVICE_URL']
      ].compact
    )

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Set-Cookie'],
      vary: ['Origin'],
      max_age: 1728000
  end
end

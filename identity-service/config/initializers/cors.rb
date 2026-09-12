Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      'https://pascalixs.fun',
      'https://auth.pascalixs.fun',
      'http://localhost:5173',
      'localhost:5173',
      ENV['WEB_PORTAL_URL'],
      ENV['IDENTITY_SERVICE_URL']
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

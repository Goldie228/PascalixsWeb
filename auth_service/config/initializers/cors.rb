Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      'https://pascalixs.fun',
      'https://auth.pascalixs.fun',
      'http://localhost:3000',
      'http://localhost:3001',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:3001',
      'http://[::1]:3000',
      'http://[::1]:3001'
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

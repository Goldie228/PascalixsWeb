Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://pascalixs.fun', 'https://auth.pascalixs.fun'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Set-Cookie'],  # Добавьте если используете
      vary: ['Origin'],                        # Обязательно!
      max_age: 1728000                         # 20 дней
  end
end
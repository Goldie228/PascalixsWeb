# Общие хелперы для request specs
module RequestHelpers
  # Современный User-Agent для проверки allow_browser versions: :modern
  MODERN_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  # Заголовки по умолчанию для HTTP-вызовов в request specs
  def default_headers
    { "User-Agent" => MODERN_USER_AGENT }
  end

  # Заглушка REDIS_CLIENT
  def stub_redis
    allow(REDIS_CLIENT).to receive(:hgetall).and_return({})
    allow(REDIS_CLIENT).to receive(:get).and_return(nil)
    allow(REDIS_CLIENT).to receive(:set).and_return(true)
    allow(REDIS_CLIENT).to receive(:del).and_return(1)
  end

  # Заглушка Karafka-продюсера
  def stub_karafka
    producer = instance_double("Karafka::Producer")
    allow(Karafka).to receive(:producer).and_return(producer)
    allow(producer).to receive(:produce_async)
  end

  # Мок current_user OpenStruct по структуре ApplicationController
  def build_mock_user(overrides = {})
    discord_account = overrides.delete(:discord_account) || OpenStruct.new(
      id: 1,
      user_id: overrides[:id] || "test-user-id",
      discord_id: "123456789",
      username: "testuser",
      discriminator: "0001",
      email: "test@example.com",
      avatar: nil
    )

    minecraft_account = overrides.delete(:minecraft_account) || nil

    defaults = {
      id: "test-user-id",
      email: "test@example.com",
      username: "testuser",
      is_registered: true,
      is_sponsor: false,
      time_zone: "UTC",
      discord_account: discord_account,
      minecraft_account: minecraft_account || OpenStruct.new(
        id: 1,
        user_id: overrides[:id] || "test-user-id",
        nickname: "TestPlayer",
        password_hash: "hashed"
      )
    }

    user = OpenStruct.new(defaults.merge(overrides))

    # Добавляем метод build_minecraft_account для совместимости с AuthController
    def user.build_minecraft_account
      OpenStruct.new(
        id: nil,
        user_id: self[:id],
        nickname: nil,
        password_hash: nil
      )
    end

    user
  end

  # Stub current_user — устанавливает @current_user и session
  def stub_current_user(user = nil)
    user ||= build_mock_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # НЕ stubbing update_current_user — даём методу работать, чтобы @current_user был установлен
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:two_factor_passed).and_return(true)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(user.id)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:time_zone).and_return('UTC')
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:alert).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:notice).and_return(nil)
    user
  end

  # Stub current_user — возвращает nil (для неавторизованных запросов)
  def stub_no_current_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
    # НЕ stubbing update_current_user — даём методу работать
  end

  # Stub HTTParty GET для auth сервиса
  def stub_auth_service_get(path, response_body:, status: 200)
    stub_request(:get, "#{ENV.fetch('IDENTITY_SERVICE_URL', 'http://auth.test')}/#{path}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end

# WebMock — блокирует реальные HTTP-запросы в тестах
# Используйте VCR для записи/воспроизведения или ручные заглушки.
#
# Примеры заглушек:
#   stub_request(:get, "https://api.example.com/users").
#     to_return(status: 200, body: '{"users": []}', headers: { 'Content-Type' => 'application/json' })
#
#   stub_request(:post, "https://api.example.com/users").
#     with(body: { user: { name: "John" } }).
#     to_return(status: 201)
#
# Конфигурация в rails_helper.rb:
#   WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Сброс WebMock после каждого теста
  config.after(:each) do
    WebMock.reset!
  end
end

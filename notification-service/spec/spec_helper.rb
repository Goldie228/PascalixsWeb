RSpec.configure do |config|
  # Сохранять статус примеров для повторного запуска failed-тестов
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Отключаем глобальные методы RSpec на Module и main
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    # Включаем цепочки кастомных матчеров в описании ошибок
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Запрещаем мокать несуществующие методы реальных объектов
    mocks.verify_partial_doubles = true
  end

  # Поведение shared_context по умолчанию (RSpec 4)
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Случайный порядок тестов для выявления зависимостей между ними
  config.order = :random

  # Фиксируем seed для воспроизводимости порядка при необходимости
  Kernel.srand config.seed
end

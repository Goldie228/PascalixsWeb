RSpec.configure do |config|
  # Отключаем глобальные методы RSpec
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Позволяет ограничить запуск отдельными примерами через тег :focus
  config.filter_run_when_matching :focus

  # Позволяет RSpec сохранять состояние между запусками
  # для --only-failures и --next-failure
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Подробный вывод при запуске отдельного файла
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  # Вывод 10 самых медленных примеров
  # в конце запуска — помогает найти медленные тесты
  config.profile_examples = 10

  # Тесты в случайном порядке — для поиска зависимостей от порядка.
  # Если нашли зависимость — фиксируйте порядок через
  # --seed 1234
  config.order = :random

  # Глобальный seed для рандомизации
  Kernel.srand config.seed
end

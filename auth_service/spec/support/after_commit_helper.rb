# Хелпер для ручного вызова after_commit колбэков в тестах
# При использовании транзакционных фикстур after_commit не срабатывает,
# потому что транзакция откатывается. Этот хелпер вызывает их вручную.
module AfterCommitHelper
  # Вызывает after_commit колбэк на записи
  def trigger_after_commit(record)
    record.run_callbacks(:commit)
  end

  # Вызывает after_create_commit колбэк на записи
  def trigger_after_create_commit(record)
    record.run_callbacks(:create)
    record.run_callbacks(:commit)
  end

  # Вызывает after_update_commit колбэк на записи
  def trigger_after_update_commit(record)
    record.run_callbacks(:update)
    record.run_callbacks(:commit)
  end
end

RSpec.configure do |config|
  config.include AfterCommitHelper
end

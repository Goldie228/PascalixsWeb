# Устанавливаем язык по умолчанию на русский
I18n.default_locale = :ru

# Доступные языки для приложения
I18n.available_locales = [:ru, :en]

# Настройка резервных языков, если перевод не найден
Rails.application.config.after_initialize do
  if I18n.respond_to?(:fallbacks)
    I18n.fallbacks[:en] = [:en, :ru]
    I18n.fallbacks[:ru] = [:ru, :en]
  end
end 
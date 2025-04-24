# Настройки интернационализации
I18n.available_locales = [:ru, :en]
I18n.default_locale = :ru

# Загрузка переводов из папки locales
I18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')] 
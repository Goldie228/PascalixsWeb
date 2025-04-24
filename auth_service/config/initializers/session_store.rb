# Настраиваем session store для обработки OmniAuth запросов
Rails.application.config.session_store :cookie_store, 
  key: '_auth_service_session',
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax # Это позволяет сессии работать при переходе от web_service к auth_service 
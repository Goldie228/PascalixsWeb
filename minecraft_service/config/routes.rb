Rails.application.routes.draw do
  root to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/#{I18n.default_locale}"), status: 302
  get "/:locale", to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/%{locale}"), 
      constraints: { locale: /#{I18n.available_locales.join("|")}/ }, 
      status: 302
end

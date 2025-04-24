# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @2.1.0
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2

# Подключаем JavaScript файлы из assets/javascripts
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.13
pin "@rails/ujs", to: "@rails--ujs.js" # @7.1.3
pin "clipboard" # @2.0.11
pin "js-cookie" # @3.0.5

pin_all_from "app/javascript/controllers", under: "controllers"

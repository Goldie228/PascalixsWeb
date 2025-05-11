pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin "@rails/actioncable", to: "@rails--actioncable.js" # @8.0.200
pin_all_from "app/javascript/channels", under: "channels"

pin_all_from "app/javascript/controllers", under: "controllers"

pin "@rails/ujs", to: "https://cdn.skypack.dev/@rails/ujs"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "clipboard", to: "https://cdn.skypack.dev/clipboard@2.0.11"
pin "timezone/timezone_setter", to: "timezone/timezone_setter.js", preload: true
pin "js-cookie" # @3.0.5

pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin "@rails/actioncable", to: "@rails--actioncable.js" # @8.0.200
pin_all_from "app/javascript/channels", under: "channels"

pin_all_from "app/javascript/controllers", under: "controllers"

# Mermaid для диаграмм (ESM версия)
pin "mermaid", to: "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs"
pin "mermaid_config", to: "mermaid_config.js"

# Wiki lazy loader для оптимизации загрузки
pin_all_from "app/javascript/wiki", under: "wiki"

pin "@rails/ujs", to: "https://cdn.skypack.dev/@rails/ujs"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "clipboard", to: "https://cdn.skypack.dev/clipboard@2.0.11"
pin "timezone/timezone_setter", to: "timezone/timezone_setter.js", preload: true
pin "js-cookie" # @3.0.5
pin "cropperjs" # @2.0.1
pin "@cropper/element", to: "@cropper--element.js" # @2.0.1
pin "@cropper/element-canvas", to: "@cropper--element-canvas.js" # @2.0.1
pin "@cropper/element-crosshair", to: "@cropper--element-crosshair.js" # @2.0.1
pin "@cropper/element-grid", to: "@cropper--element-grid.js" # @2.0.1
pin "@cropper/element-handle", to: "@cropper--element-handle.js" # @2.0.1
pin "@cropper/element-image", to: "@cropper--element-image.js" # @2.0.1
pin "@cropper/element-selection", to: "@cropper--element-selection.js" # @2.0.1
pin "@cropper/element-shade", to: "@cropper--element-shade.js" # @2.0.1
pin "@cropper/element-viewer", to: "@cropper--element-viewer.js" # @2.0.1
pin "@cropper/elements", to: "@cropper--elements.js" # @2.0.1
pin "@cropper/utils", to: "@cropper--utils.js" # @2.0.1

import "@hotwired/turbo-rails"
import Rails from "@rails/ujs"
Rails.start()

import ClipboardJS from "clipboard";
window.ClipboardJS = ClipboardJS;

document.addEventListener('turbo:load', function() {
  if (window.ClipboardJS) {
    new ClipboardJS('[data-clipboard-text]');
  }
});

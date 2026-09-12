import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initClipboard()
  }

  initClipboard() {
    const clipboardButtons = this.element.querySelectorAll('[data-clipboard-text]')

    clipboardButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const text = btn.dataset.clipboardText
        navigator.clipboard.writeText(text).then(() => {
          if (typeof showNotification === 'function') {
            showNotification('IP copied!')
          }
        }).catch(() => {
          if (typeof showAlertNotification === 'function') {
            showAlertNotification('Copy failed')
          }
        })
      })
    })
  }
}

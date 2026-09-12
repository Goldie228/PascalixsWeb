import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notification", "alertNotification", "notificationText", "alertNotificationText"]

  connect() {
    this.timeout = null
  }

  show(event) {
    const message = event?.detail?.message || event?.target?.dataset?.message || ''
    const type = event?.detail?.type || 'info'
    const duration = event?.detail?.duration || 3000

    this.clearTimeout()

    const el = type === 'error' ? this.alertNotificationTarget : this.notificationTarget
    const textEl = type === 'error' ? this.alertNotificationTextTarget : this.notificationTextTarget

    if (!el || !textEl) return

    textEl.textContent = message
    el.classList.remove('hidden')

    this.timeout = setTimeout(() => this.hide(type), duration)
  }

  hide(type = 'info') {
    this.clearTimeout()
    const el = type === 'error' ? this.alertNotificationTarget : this.notificationTarget
    if (el) el.classList.add('hidden')
  }

  close(event) {
    const el = event.target.closest('#notification, #alert-notification')
    if (el) el.classList.add('hidden')
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}

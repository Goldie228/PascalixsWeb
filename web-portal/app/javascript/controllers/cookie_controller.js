import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { acceptNotification: String }
  static targets = ["alert"]

  connect() {
    if (!localStorage.getItem('cookieAccepted')) {
      setTimeout(() => this.showAlert(), 5000)
    }
  }

  async accept() {
    localStorage.setItem('cookieAccepted', 'true')
    await this.hideAlert()
    const message = this.acceptNotificationValue || this.acceptTarget?.dataset?.notification || ''
    if (message && typeof showNotification === 'function') {
      showNotification(message)
    }
  }

  showAlert() {
    const alert = this.alertTarget || this.element
    alert.classList.remove('hidden')
    alert.classList.add('animate-fade-in')
  }

  async hideAlert() {
    const alert = this.alertTarget || this.element
    alert.classList.add('animate-fade-out')
    await new Promise(resolve => {
      alert.addEventListener('animationend', resolve, { once: true })
    })
    alert.classList.add('hidden')
  }
}

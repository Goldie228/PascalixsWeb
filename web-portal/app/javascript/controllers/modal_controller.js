import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Expose methods to window for inline onclick handlers
    this.bindMethodsToWindow()
  }

  disconnect() {
    this.unbindMethodsFromWindow()
  }

  open(modalId) {
    const modal = document.getElementById(modalId) || this.element.querySelector(`#${modalId}`)
    if (modal && modal.showModal) {
      modal.showModal()
    }
  }

  close(modalId) {
    const modal = document.getElementById(modalId) || this.element.querySelector(`#${modalId}`)
    if (modal && modal.close) {
      modal.close()
    }
  }

  switchModal(fromId, toId) {
    this.close(fromId)
    this.open(toId)
  }

  bindMethodsToWindow() {
    const actions = this.data.keys().filter(key => key.startsWith('action-'))
    actions.forEach(key => {
      const methodName = this.data.get(key)
      if (methodName && this[methodName]) {
        const windowName = key.replace('action-', '')
        window[windowName] = this[methodName].bind(this)
      }
    })
  }

  unbindMethodsFromWindow() {
    const actions = this.data.keys().filter(key => key.startsWith('action-'))
    actions.forEach(key => {
      const windowName = key.replace('action-', '')
      delete window[windowName]
    })
  }
}

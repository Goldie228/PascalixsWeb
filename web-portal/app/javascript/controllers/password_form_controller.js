import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitBtn", "submitText", "spinner", "password", "toggle"]
  static classes = ["error"]

  connect() {
    this.setupPasswordToggles()
    this.setupFormSubmission()
    if (this.hasPasswordTarget) {
      this.setupPasswordConfirmationCheck()
    }
  }

  setupPasswordToggles() {
    const toggles = this.element.querySelectorAll('.toggle-password, [data-password-form-controller="toggle"]')
    toggles.forEach(toggle => {
      const passwordId = toggle.getAttribute('data-toggle') || toggle.dataset.passwordId
      const password = passwordId ? document.getElementById(passwordId) : null
      if (password) {
        toggle.addEventListener('click', () => this.togglePassword(password, toggle))
      }
    })
  }

  togglePassword(password, toggle) {
    const isPassword = password.type === 'password'
    password.type = isPassword ? 'text' : 'password'

    if (isPassword) {
      toggle.innerHTML = '<svg class="w-6 h-6 text-white" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-width="2" d="M21 12c0 1.2-4.03 6-9 6s-9-4.8-9-6c0-1.2 4.03-6 9-6s9 4.8 9 6Z"/><path stroke="currentColor" stroke-width="2" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/></svg>'
    } else {
      toggle.innerHTML = '<svg class="w-6 h-6 text-gray-300" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.933 13.909A4.357 4.357 0 0 1 3 12c0-1 4-6 9-6m7.6 3.8A5.068 5.068 0 0 1 21 12c0 1-3 6-9 6-.314 0-.62-.014-.918-.04M5 19 19 5m-4 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/></svg>'
    }
  }

  togglePasswordViaAction() {
    if (this.hasPasswordTarget && this.hasToggleTarget) {
      this.togglePassword(this.passwordTarget, this.toggleTarget)
    }
  }

  setupPasswordConfirmationCheck() {
    const confirmInput = this.element.querySelector('#password_confirmation, [name="password_confirmation"]')
    const newPasswordInput = this.element.querySelector('#new_password, [name="new_password"]')
    const errorEl = this.element.querySelector('#password_confirmation_error, [id$="_password_error"]')

    if (!confirmInput || !newPasswordInput || !errorEl) return

    const password = newPasswordInput.value
    const confirm = confirmInput.value

    if (confirm && password !== confirm) {
      errorEl.textContent = confirmInput.dataset.mismatchText || 'Passwords do not match'
    } else {
      errorEl.textContent = ''
    }

    confirmInput.addEventListener('input', () => {
      const p = newPasswordInput.value
      const c = confirmInput.value
      if (c && p !== c) {
        errorEl.textContent = confirmInput.dataset.mismatchText || 'Passwords do not match'
      } else {
        errorEl.textContent = ''
      }
    })
  }

  setupFormSubmission() {
    const form = this.formTarget || this.element.querySelector('form')
    if (!form) return

    form.addEventListener('submit', async (e) => {
      e.preventDefault()
      this.clearErrors()
      this.showLoading()

      try {
        const formData = new FormData(form)
        const jsonData = Object.fromEntries(formData.entries())
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
        const locale = document.querySelector('meta[name="locale"]')?.content || 'en'

        const endpoint = form.dataset.endpoint || form.action
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken,
            'X-Locale': locale
          },
          body: JSON.stringify(jsonData)
        })

        const data = await response.json()

        if (!response.ok) throw data

        this.handleSuccess(data)
      } catch (error) {
        this.handleError(error)
      } finally {
        this.hideLoading()
      }
    })
  }

  clearErrors() {
    this.element.querySelectorAll('[id$="_error"]').forEach(el => {
      if (el) el.textContent = ''
    })
  }

  showLoading() {
    if (this.hasSubmitTextTarget) this.submitTextTarget.textContent = this.submitTextTarget.dataset.loadingText || 'Loading...'
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = true
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove('hidden')
  }

  hideLoading() {
    if (this.hasSubmitTextTarget) this.submitTextTarget.textContent = this.submitTextTarget.dataset.defaultText || 'Submit'
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = false
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add('hidden')
  }

  handleSuccess(data) {
    const form = this.formTarget || this.element.querySelector('form')
    form.reset()

    const redirect = data.redirect_to || data.redirectUrl
    if (redirect) {
      window.location.href = redirect
      return
    }

    const message = data.message || data.success
    if (typeof showNotification === 'function' && message) {
      showNotification(message)
    }
  }

  handleError(error) {
    if (error.errors) {
      Object.entries(error.errors).forEach(([field, message]) => {
        const errorEl = this.element.getElementById(`${field}_error`) || this.element.querySelector(`[id="${field}_error"]`)
        if (errorEl) errorEl.textContent = Array.isArray(message) ? message[0] : message
      })
    } else {
      const message = error.message || 'An error occurred'
      if (typeof showAlertNotification === 'function') {
        showAlertNotification(message)
      } else if (typeof showNotification === 'function') {
        showNotification(message)
      }
    }
  }
}

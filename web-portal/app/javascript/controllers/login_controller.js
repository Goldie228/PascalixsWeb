import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "toggle", "submitButton"]

  connect() {
    this.setupPasswordToggle()
    this.setupFormValidation()
  }

  togglePassword() {
    const pw = this.passwordTarget
    const toggle = this.toggleTarget
    if (!pw || !toggle) return

    const isPassword = pw.type === 'password'
    pw.type = isPassword ? 'text' : 'password'

    if (isPassword) {
      toggle.innerHTML = '<svg class="w-6 h-6 text-white" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-width="2" d="M21 12c0 1.2-4.03 6-9 6s-9-4.8-9-6c0-1.2 4.03-6 9-6s9 4.8 9 6Z"/><path stroke="currentColor" stroke-width="2" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/></svg>'
      toggle.setAttribute('aria-label', toggle.dataset.showLabel || 'Show password')
    } else {
      toggle.innerHTML = '<svg class="w-6 h-6 text-gray-300" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.933 13.909A4.357 4.357 0 0 1 3 12c0-1 4-6 9-6m7.6 3.8A5.068 5.068 0 0 1 21 12c0 1-3 6-9 6-.314 0-.62-.014-.918-.04M5 19 19 5m-4 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/></svg>'
      toggle.setAttribute('aria-label', toggle.dataset.hideLabel || 'Hide password')
    }
  }

  setupFormValidation() {
    const form = this.element.querySelector('form')
    if (!form) return

    form.addEventListener('submit', async (e) => {
      e.preventDefault()
      this.clearErrors()

      const nickname = form.nickname?.value?.trim() || ''
      const password = form.password?.value || ''

      if (!nickname || !password) {
        this.showFieldError('nickname', nickname ? '' : 'Nickname is required')
        this.showFieldError('password', password ? '' : 'Password is required')
        this.enableSubmit()
        return
      }

      this.disableSubmit()

      try {
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
        const response = await fetch(form.action, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json'
          },
          body: JSON.stringify({ nickname, password })
        })

        const json = await response.json()
        if (json.redirect_url) {
          this.dispatch('login-success', { value: json.redirect_url })
        }
      } catch (error) {
        this.dispatch('login-error', { message: 'Login failed' })
        this.enableSubmit()
      }
    })
  }

  clearErrors() {
    this.element.querySelectorAll('.error-message').forEach(msg => {
      msg.classList.add('hidden')
      msg.textContent = ''
    })
    this.element.querySelectorAll('input').forEach(input => {
      input.classList.remove('input-error')
    })
  }

  showFieldError(field, message) {
    if (!message) return
    const input = this.element.querySelector(`[name="${field}"]`)
    if (input) {
      const formControl = input.closest('.form-control')
      if (formControl) {
        const errorContainer = formControl.querySelector('.error-message')
        if (errorContainer) {
          errorContainer.textContent = message
          errorContainer.classList.remove('hidden')
          input.classList.add('input-error')
        }
      }
    }
  }

  disableSubmit() {
    const btn = this.submitButtonTarget || this.element.querySelector('button[type="submit"]')
    if (btn) {
      btn.disabled = true
      btn.innerHTML = '<span class="loading loading-spinner"></span> Submitting...'
    }
  }

  enableSubmit() {
    const btn = this.submitButtonTarget || this.element.querySelector('button[type="submit"]')
    if (btn) {
      btn.disabled = false
      btn.innerHTML = btn.dataset.defaultText || 'Login'
    }
  }
}

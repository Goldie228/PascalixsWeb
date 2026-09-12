import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitBtn", "submitText", "spinner", "emailError"]

  connect() {
    this.setupForm()
  }

  setupForm() {
    const form = this.formTarget || this.element.querySelector('form')
    if (!form) return

    form.addEventListener('submit', async (e) => {
      e.preventDefault()

      const emailError = this.emailErrorTarget || this.element.querySelector('#email_error')
      const submitBtn = this.submitBtnTarget || this.element.querySelector('#submit-btn')
      const submitText = this.submitTextTarget || this.element.querySelector('#submit-text')
      const spinner = this.spinnerTarget || this.element.querySelector('#spinner')

      if (emailError) emailError.textContent = ''

      if (submitText) submitText.textContent = 'Sending...'
      if (submitBtn) submitBtn.disabled = true
      if (spinner) spinner.classList.remove('hidden')

      try {
        const formData = new FormData(form)
        const email = formData.get('email')

        if (!email) {
          if (emailError) emailError.textContent = 'Email is required'
          this.restoreButton(submitBtn, submitText, spinner)
          return
        }

        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
        const response = await fetch('email_login/verify_email', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken
          },
          body: JSON.stringify({ email })
        })

        const data = await response.json()

        if (!response.ok) {
          if (data.errors?.email) {
            if (emailError) emailError.textContent = data.errors.email[0]
          } else {
            if (typeof showAlertNotification === 'function') {
              showAlertNotification(data.message || 'Error')
            }
          }
          this.restoreButton(submitBtn, submitText, spinner)
          return
        }

        window.location.href = '/email_login/pending'
      } catch (error) {
        if (typeof showAlertNotification === 'function') {
          showAlertNotification(error.message || 'Error')
        }
        this.restoreButton(submitBtn, submitText, spinner)
      }
    })
  }

  restoreButton(submitBtn, submitText, spinner) {
    if (submitBtn) submitBtn.disabled = false
    if (submitText) submitText.textContent = submitText.dataset.defaultText || 'Continue'
    if (spinner) spinner.classList.add('hidden')
  }
}

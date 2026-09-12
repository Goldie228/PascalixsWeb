import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "charCount", "submitButton", "form"]

  connect() {
    this.init()
  }

  init() {
    const textarea = this.textareaTarget
    const charCount = this.charCountTarget
    const submitBtn = this.submitButtonTarget

    if (!textarea) return

    const originalValue = textarea.value || ""
    this.updateCount(textarea, charCount, submitBtn, originalValue)

    textarea.addEventListener('input', () => {
      this.updateCount(textarea, charCount, submitBtn, originalValue)
    })
  }

  updateCount(textarea, charCount, submitBtn, originalValue) {
    if (charCount) {
      charCount.textContent = `${textarea.value.length}/250`
    }

    if (submitBtn) {
      const trimmed = textarea.value.trim()
      const changed = trimmed.length > 0 && textarea.value !== originalValue
      submitBtn.disabled = !changed
    }
  }

  submit(event) {
    const form = this.formTarget || this.element.querySelector('form')
    const submitBtn = this.submitButtonTarget

    if (form && submitBtn) {
      event.preventDefault()
      submitBtn.disabled = true
      submitBtn.textContent = "<%= j t('player_info.modal.please_wait') %>"
      form.submit()
    }
  }

  close() {
    const modal = document.getElementById('about_me_modal')
    if (modal) modal.close()
  }
}

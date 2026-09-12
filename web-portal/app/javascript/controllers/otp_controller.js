import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digitInput", "hiddenInput", "timer", "resendButton"]

  connect() {
    this.timerInterval = null
    this.initOTPInputs()
    this.initTimer()
    this.keepButtonEnabled()
  }

  disconnect() {
    if (this.timerInterval) clearInterval(this.timerInterval)
  }

  initOTPInputs() {
    const inputs = this.digitInputTargets
    const hidden = this.hiddenInputTarget

    inputs.forEach((input, index) => {
      input.addEventListener('input', (e) => {
        e.target.value = e.target.value.replace(/\D/g, '')
        if (e.target.value.length === 1 && index < inputs.length - 1) {
          inputs[index + 1].focus()
        }
        this.updateHiddenInput(inputs, hidden)
      })

      input.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && e.target.value === '' && index > 0) {
          inputs[index - 1].focus()
        }
        if (e.keyCode === 37 && index > 0) inputs[index - 1].focus()
        if (e.keyCode === 39 && index < inputs.length - 1) inputs[index + 1].focus()
        this.updateHiddenInput(inputs, hidden)
      })

      input.addEventListener('paste', (e) => {
        const pasted = e.clipboardData.getData('text').replace(/\s/g, '')
        if (pasted.length === inputs.length) {
          pasted.split('').forEach((char, i) => {
            if (inputs[i]) inputs[i].value = char
          })
          inputs[inputs.length - 1].focus()
          this.updateHiddenInput(inputs, hidden)
        }
        e.preventDefault()
      })
    })
  }

  updateHiddenInput(inputs, hidden) {
    if (hidden) {
      hidden.value = Array.from(inputs).map(i => i.value).join('')
    }
  }

  initTimer() {
    const timerEl = this.timerTarget
    if (!timerEl) return

    const validUntilEl = document.getElementById('otp-valid-until')
    let duration = 120

    if (validUntilEl) {
      const timestamp = parseInt(validUntilEl.value, 10)
      if (!isNaN(timestamp)) {
        const date = new Date(timestamp)
        const now = new Date()
        const diff = Math.floor((date - now) / 1000)
        if (diff > 0) duration = diff
      }
    }

    this.startTimer(duration)
  }

  startTimer(duration) {
    if (this.timerInterval) clearInterval(this.timerInterval)

    const endTime = Date.now() + (duration * 1000)
    const update = () => {
      const timeLeft = Math.max(0, endTime - Date.now())
      if (timeLeft === 0) {
        this.handleTimerEnd()
        return
      }
      const minutes = Math.floor(timeLeft / 60000)
      const seconds = Math.floor((timeLeft % 60000) / 1000)
      if (this.timerTarget) {
        this.timerTarget.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`
        this.timerTarget.classList.remove('hidden')
      }
      if (this.resendButtonTarget) {
        this.resendButtonTarget.classList.add('hidden')
      }
    }

    update()
    this.timerInterval = setInterval(update, 1000)
  }

  handleTimerEnd() {
    if (this.timerTarget) {
      this.timerTarget.textContent = '0:00'
      this.timerTarget.classList.add('hidden')
    }
    if (this.resendButtonTarget) {
      this.resendButtonTarget.classList.remove('hidden')
    }
    if (this.timerInterval) clearInterval(this.timerInterval)
  }

  keepButtonEnabled() {
    const form = this.element.querySelector('form')
    const submitBtn = form?.querySelector('button[type="submit"], input[type="submit"]')
    if (!submitBtn) return

    submitBtn.disabled = false
    submitBtn.removeAttribute('disabled')

    const keepEnabled = () => {
      submitBtn.disabled = false
      submitBtn.removeAttribute('disabled')
    }

    form?.addEventListener('input', keepEnabled)
    form?.addEventListener('change', keepEnabled)

    const observer = new MutationObserver(mutations => {
      mutations.forEach(m => {
        if (m.attributeName === 'disabled') keepEnabled()
      })
    })
    observer.observe(submitBtn, { attributes: true, attributeFilter: ['disabled'] })

    setInterval(keepEnabled, 500)
  }
}

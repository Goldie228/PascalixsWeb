import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "error", "list", "noMutes", "payBtn", "totalPrice", "punishmentsList"]

  connect() {
    window.openUnmuteModal = () => this.open()
    this.init()
  }

  disconnect() {
    delete window.openUnmuteModal
  }

  init() {
  }

  open() {
    this.resetState()
    const modal = document.getElementById('unmute_modal')
    if (modal) modal.showModal()
    this.loadData()
  }

  resetState() {
    this.hideTarget(this.list)
    this.hideTarget(this.noMutes)
    this.hideTarget(this.error)
    this.hideTarget(this.payBtn)
    this.showTarget(this.loading)
    if (this.punishmentsListTarget) this.punishmentsListTarget.innerHTML = ''
  }

  loadData() {
    fetch('/get_unmute_price', {
      credentials: 'include',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      }
    })
    .then(response => {
      if (!response.ok) throw new Error(I18n.t('views.punishments.unmute_modal.js_load_error') || 'Loading error')
      return response.json()
    })
    .then(data => this.renderData(data))
    .catch(error => this.showError(error))
    .finally(() => this.hideTarget(this.loading))
  }

  renderData(data) {
    if (!data.punishments || data.punishments.length === 0) {
      this.showTarget(this.noMutes)
      return
    }

    if (this.punishmentsListTarget) {
      this.punishmentsListTarget.innerHTML = ''
      data.punishments.forEach(p => {
        const item = document.createElement('div')
        item.className = 'flex justify-between items-center p-3 bg-[#1A1A1A] rounded-lg'
        item.innerHTML = `
          <div class="flex-1">
            <p class="text-white font-medium">${p.reason || I18n.t('views.punishments.unmute_modal.js_no_reason') || 'Reason not specified'}</p>
          </div>
          <div class="text-amber-400 font-semibold">${p.price} $</div>
        `
        this.punishmentsListTarget.appendChild(item)
      })
    }

    if (this.totalPriceTarget) {
      this.totalPriceTarget.textContent = `${data.total_price || 0} $`
    }

    this.showTarget(this.list)
    this.showTarget(this.payBtn)
  }

  confirmPayment(event) {
    const priceText = this.totalPriceTarget?.textContent || '0 $'
    const price = parseFloat(priceText.replace(/[^0-9.]/g, ''))
    
    if (!window.currentUserId) {
      console.error('User ID not available')
      return
    }

    if (!price || price <= 0) {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification(I18n.t('views.punishments.unmute_modal.js_no_mutes_for_payment') || 'No mutes for payment')
      }
      return
    }

    if (typeof openPurchaseModal === 'function') {
      openPurchaseModal('unmute', window.currentUserId, window.currentUserId, price)
      const modal = document.getElementById('unmute_modal')
      if (modal) modal.close()
    } else {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification(I18n.t('views.punishments.unmute_modal.js_payment_system_unavailable') || 'Payment system unavailable')
      }
    }
  }

  showTarget(el) { if (el) el.classList.remove('hidden') }
  hideTarget(el) { if (el) el.classList.add('hidden') }

  showError(error) {
    if (this.errorTarget) {
      this.errorTarget.textContent = error.message || I18n.t('views.punishments.unmute_modal.loading_error') || 'Unknown error'
      this.showTarget(this.errorTarget)
    }
  }
}

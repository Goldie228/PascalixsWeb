import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "error", "list", "noBans", "payBtn", "totalPrice", "punishmentsList"]

  connect() {
    this.init()
  }

  init() {
    this.openModal()
  }

  open() {
    this.resetState()
    const modal = document.getElementById('unban_modal')
    if (modal) modal.showModal()
    this.loadData()
  }

  resetState() {
    this.hide(this.list)
    this.hide(this.noBans)
    this.hide(this.error)
    this.hide(this.payBtn)
    this.show(this.loading)
    if (this.punishmentsList) this.punishmentsList.innerHTML = ''
  }

  loadData() {
    fetch('/get_unban_price', {
      credentials: 'include',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      }
    })
    .then(response => {
      if (!response.ok) throw new Error('Loading error')
      return response.json()
    })
    .then(data => this.renderData(data))
    .catch(error => this.showError(error))
    .finally(() => this.hide(this.loading))
  }

  renderData(data) {
    if (!data.punishments || data.punishments.length === 0) {
      this.show(this.noBans)
      return
    }

    if (this.punishmentsList) {
      this.punishmentsList.innerHTML = ''
      data.punishments.forEach(p => {
        const item = document.createElement('div')
        item.className = 'flex justify-between items-center p-3 bg-[#1A1A1A] rounded-lg'
        item.innerHTML = `
          <div class="flex-1">
            <p class="text-white font-medium">${p.reason || 'Reason not specified'}</p>
          </div>
          <div class="text-amber-400 font-semibold">${p.price} $</div>
        `
        this.punishmentsList.appendChild(item)
      })
    }

    if (this.totalPrice) {
      this.totalPrice.textContent = `${data.total_price || 0} $`
    }

    this.show(this.list)
    this.show(this.payBtn)

    if (this.payBtn) {
      this.payBtn.onclick = () => this.confirmPayment(data.total_price)
    }
  }

  confirmPayment(price) {
    if (!window.currentUserId) return

    if (!price || price <= 0) {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification('No bans for payment')
      }
      return
    }

    if (typeof openPurchaseModal === 'function') {
      openPurchaseModal('unban', window.currentUserId, window.currentUserId, price)
      const modal = document.getElementById('unban_modal')
      if (modal) modal.close()
    } else {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification('Payment system unavailable')
      }
    }
  }

  show(el) { if (el) el.classList.remove('hidden') }
  hide(el) { if (el) el.classList.add('hidden') }

  showError(error) {
    if (this.error) {
      this.error.textContent = error.message || 'Unknown error'
      this.show(this.error)
    }
  }
}

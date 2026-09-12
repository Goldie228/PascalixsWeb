import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    window.showUpdateConfirm = (type) => this.showUpdateConfirm(type)
    this.loadProducts()
  }

  disconnect() {
    delete window.showUpdateConfirm
  }

  async loadProducts() {
    try {
      const response = await fetch('/admin/products_data')
      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const newContainer = doc.querySelector('#productsContainer')
      if (newContainer && this.containerTarget) {
        this.containerTarget.innerHTML = newContainer.innerHTML
      }
    } catch (error) {
      console.error('Failed to load products:', error)
    }
  }

  async showUpdateConfirm(productType) {
    const input = document.getElementById(`price-input-${productType}`)
    const btn = document.getElementById(`update-btn-${productType}`)
    if (!input || !btn) return

    const newPrice = input.value
    if (!newPrice || parseFloat(newPrice) < 0) {
      input.focus()
      return
    }

    btn.disabled = true
    btn.textContent = 'Updating...'

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(`/admin/products/update_price/${productType}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ price: parseFloat(newPrice) })
      })

      const data = await response.json()

      if (data.success) {
        const currentPriceEl = document.getElementById(`current-price-${productType}`)
        if (currentPriceEl) {
          currentPriceEl.textContent = `${data.newPrice} $`
        }
        input.value = data.newPrice
        if (typeof showNotification === 'function') {
          showNotification(data.message || 'Price updated successfully')
        }
      } else {
        if (typeof showAlertNotification === 'function') {
          showAlertNotification(data.message || 'Failed to update price')
        }
      }
    } catch (error) {
      console.error('Error updating price:', error)
      if (typeof showAlertNotification === 'function') {
        showAlertNotification('Network error')
      }
    } finally {
      btn.disabled = false
      btn.textContent = btn.dataset.defaultText || 'Update Price'
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["priceElement"]

  connect() {
    this.authUrl = "<%= ENV['IDENTITY_SERVICE_URL'] || '' %>"
  }

  async open() {
    const priceElement = this.priceTarget
    if (priceElement) {
      priceElement.textContent = ''
      priceElement.classList.remove('text-red-500')
    }
    const modal = document.getElementById('pass_purchase_modal')
    if (modal) {
      modal.showModal()
      await this.updatePrice()
    }
  }

  close() {
    const modal = document.getElementById('pass_purchase_modal')
    if (modal) modal.close()
  }

  async updatePrice() {
    const priceElement = this.priceTarget
    if (!priceElement) return
    priceElement.innerHTML = '<span class="loading loading-spinner loading-md"></span>'
    const price = await this.getPassPrice()
    if (price !== null) {
      priceElement.textContent = price + " USD"
    } else {
      priceElement.textContent = 'Цена недоступна'
      priceElement.classList.add('text-red-500')
      this.showNotification('Не удалось получить цену продукта. Пожалуйста, попробуйте позже.', 'error')
    }
  }

  async getPassPrice() {
    try {
      const url = this.authUrl && !this.authUrl.includes('<%') ? `${this.authUrl}/api/v1/product/pass_purchase` : `${this.authUrl}/api/v1/product/pass_purchase`
      const response = await fetch(url, { method: 'GET', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken() }, credentials: 'same-origin' })
      if (response.ok) { const data = await response.json(); return data.price }
      return null
    } catch (error) { console.error('Исключение при получении цены продукта:', error); return null }
  }

  getCsrfToken() { return document.querySelector('meta[name="csrf-token"]')?.content || '' }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 animate-fadeIn ${type === 'error' ? 'bg-red-500' : type === 'success' ? 'bg-green-500' : 'bg-blue-500'} text-white`
    notification.textContent = message
    document.body.appendChild(notification)
    setTimeout(() => { notification.remove() }, 5000)
  }
}

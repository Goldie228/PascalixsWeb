import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.openSponsorModal = () => this.open()
  }

  disconnect() {
    delete window.openSponsorModal
  }

  open() {
    const modal = document.getElementById('sponsor_modal')
    if (modal) modal.showModal()
  }

  confirm() {
    const currentUserId = window.currentUserId || document.body.dataset.currentUserId
    if (!currentUserId) {
      console.error('User ID not available')
      return
    }

    if (typeof openPurchaseModal === 'function') {
      openPurchaseModal('sponsor', currentUserId, currentUserId)
      const sponsorModal = document.getElementById('sponsor_modal')
      if (sponsorModal) sponsorModal.close()
    } else {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification(I18n.t('views.shared.sponsor_modal.payment_unavailable') || 'Payment system unavailable')
      }
    }
  }
}

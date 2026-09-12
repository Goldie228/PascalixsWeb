import { Controller } from "@hotwired/stimulus"
import UserSelectionController from './user_selection_controller'

export default class extends Controller {
  static targets = ["selectedUserContainer", "selectedUserAvatar", "selectedUserNickname", "selectUserBtn", "giftBtn"]

  connect() {
    this.selectedUser = null
    this.selectionController = null
  }

  open() {
    const modal = document.getElementById('gift_pass_modal')
    if (modal) modal.showModal()
    this.resetState()
    this.initSelectionModal()
  }

  resetState() {
    this.selectedUser = null
    if (this.selectedUserContainer) this.selectedUserContainer.style.display = 'none'
    if (this.selectUserBtn) this.selectUserBtn.style.display = 'block'
    if (this.giftBtn) this.giftBtn.disabled = true
  }

  initSelectionModal() {
    const selectionModal = document.getElementById('user_selection_modal')
    if (!selectionModal) return

    this.selectionController = new UserSelectionController({ element: selectionModal })
    this.selectionController.bindings = []
    this.selectionController.isLoading = false
    this.selectionController.currentPage = 1
    this.selectionController.searchTimeout = null

    const searchInput = selectionModal.querySelector('#user_search')
    if (searchInput) {
      searchInput.addEventListener('input', () => {
        clearTimeout(this.selectionController.searchTimeout)
        this.selectionController.searchTimeout = setTimeout(() => {
          this.selectionController.loadUsers(1)
        }, 300)
      })
    }

    selectionModal.addEventListener('close', () => {
      if (this.selectionController?.timerInterval) {
        clearInterval(this.selectionController.timerInterval)
      }
    })
  }

  openUserSelection() {
    const modal = document.getElementById('user_selection_modal')
    if (modal) {
      modal.showModal()
      if (this.selectionController) {
        this.selectionController.loadUsers()
      }
    }
  }

  selectUser(user) {
    this.selectedUser = user

    if (this.selectedUserAvatar) this.selectedUserAvatar.src = user.avatar_url
    if (this.selectedUserNickname) this.selectedUserNickname.textContent = user.nickname

    if (this.selectedUserContainer) this.selectedUserContainer.style.display = 'block'
    if (this.selectUserBtn) this.selectUserBtn.style.display = 'none'
    if (this.giftBtn) this.giftBtn.disabled = false

    const modal = document.getElementById('user_selection_modal')
    if (modal) modal.close()
  }

  confirmGift() {
    if (!this.selectedUser) return

    if (typeof openPurchaseModal === 'function') {
      const currentUserId = document.body.dataset.currentUserId || '<%= current_user&.id %>'
      openPurchaseModal('pass_gift', currentUserId, this.selectedUser.uuid)

      const modal = document.getElementById('gift_pass_modal')
      if (modal) modal.close()
    } else {
      if (typeof showAlertNotification === 'function') {
        showAlertNotification('Payment system unavailable')
      }
    }
  }
}

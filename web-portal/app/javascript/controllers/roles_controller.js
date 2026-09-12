import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.init()
  }

  init() {
    const showMore = this.element.querySelector('#show-more')
    const hiddenRoles = this.element.querySelector('#hidden-roles')

    if (showMore && hiddenRoles) {
      showMore.addEventListener('click', () => this.toggleRoles())
    }

    const collapseBtn = hiddenRoles?.querySelector('[onclick*="toggleRoles"]')
    if (collapseBtn) {
      collapseBtn.addEventListener('click', () => this.toggleRoles())
    }
  }

  toggleRoles() {
    const hiddenRoles = this.element.querySelector('#hidden-roles')
    const showMore = this.element.querySelector('#show-more')

    if (!hiddenRoles || !showMore) return

    hiddenRoles.classList.toggle('hidden')
    showMore.classList.toggle('hidden')

    if (!hiddenRoles.classList.contains('hidden')) {
      hiddenRoles.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }
}

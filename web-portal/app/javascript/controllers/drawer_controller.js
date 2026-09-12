import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer"]

  connect() {
    this.isAnimating = false
    this.drawerVisible = false
    this._toggleBound = this.toggle.bind(this)
    this.bindTriggers()
    this.bindGlobalClick()
    this.bindResize()
  }

  disconnect() {
    this.unbindTriggers()
    this.unbindGlobalClick()
    window.removeEventListener('resize', this.resizeHandler)
  }

  toggle() {
    if (this.isAnimating) return

    const drawer = this.drawerTarget || this.element
    if (!drawer) return

    this.isAnimating = true

    if (this.drawerVisible) {
      this.closeDrawer(drawer)
    } else {
      this.openDrawer(drawer)
    }
  }

  openDrawer(drawer) {
    drawer.classList.remove('hidden')
    drawer.classList.add('visible')

    const isMobile = window.innerWidth <= 767
    drawer.style.transform = isMobile ? 'translateY(0)' : 'translateX(0)'
    drawer.style.opacity = '1'
    drawer.classList.add('animate-fade-in')

    const handleOpen = () => {
      drawer.classList.remove('animate-fade-in')
      this.drawerVisible = true
      this.isAnimating = false
      drawer.removeEventListener('animationend', handleOpen)
    }

    drawer.addEventListener('animationend', handleOpen, { once: true })
  }

  closeDrawer(drawer) {
    drawer.classList.remove('animate-fade-in')
    drawer.classList.add('animate-fade-out')

    const handleClose = () => {
      drawer.classList.remove('animate-fade-out')
      drawer.classList.remove('visible')
      drawer.classList.add('hidden')
      this.drawerVisible = false
      this.isAnimating = false
      drawer.removeEventListener('animationend', handleClose)
    }

    drawer.addEventListener('animationend', handleClose, { once: true })
  }

  bindTriggers() {
    const triggers = document.querySelectorAll('[data-drawer-trigger]')
    triggers.forEach(trigger => {
      trigger.addEventListener('click', (event) => {
        event.stopPropagation()
        this._toggleBound()
      })
    })
  }

  unbindTriggers() {
    const triggers = document.querySelectorAll('[data-drawer-trigger]')
    triggers.forEach(trigger => {
      trigger.removeEventListener('click', this._toggleBound)
    })
  }

  bindGlobalClick() {
    this.globalClickHandler = (event) => {
      const drawer = this.drawerTarget || this.element
      const triggers = document.querySelectorAll('[data-drawer-trigger]')
      if (!drawer || triggers.length === 0) return

      if (
        this.drawerVisible &&
        !event.target.closest('#account-drawer') &&
        !event.target.closest('[data-drawer-trigger]')
      ) {
        this.toggle()
      }
    }
    document.addEventListener('click', this.globalClickHandler)
  }

  unbindGlobalClick() {
    if (this.globalClickHandler) {
      document.removeEventListener('click', this.globalClickHandler)
    }
  }

  bindResize() {
    this.resizeHandler = () => {
      if (this.drawerVisible) {
        const drawer = this.drawerTarget || this.element
        const isMobile = window.innerWidth <= 767
        drawer.style.transform = isMobile ? 'translateY(0)' : 'translateX(0)'
      }
    }
    window.addEventListener('resize', this.resizeHandler)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "button", "content"]

  connect() {
    this._resizeHandler = () => this.adjustButtonPosition()
    window.addEventListener('resize', this._resizeHandler)
    this.init()
  }

  disconnect() {
    window.removeEventListener('resize', this._resizeHandler)
  }

  init() {
    // Initialize drawer state from localStorage
  }

  toggle() {
    const currentState = localStorage.getItem('drawerOpen') === 'true'
    const newState = !currentState
    localStorage.setItem('drawerOpen', newState.toString())
    this.applyDrawerState(newState)
  }

  applyDrawerState(open) {
    const drawer = this.drawerTarget || document.getElementById('drawer-container')
    const button = this.buttonTarget || document.getElementById('drawer-toggle-btn')
    const content = this.contentTarget || document.getElementById('main-content')

    if (open) {
      drawer?.classList.remove('-translate-x-full')
      content?.classList.add('ml-[260px]')
      if (button) {
        button.style.left = '290px'
        button.innerHTML = '&lt;'
      }
    } else {
      drawer?.classList.add('-translate-x-full')
      content?.classList.remove('ml-[260px]')
      if (button) {
        button.style.left = '30px'
        button.innerHTML = '&gt;'
      }
    }
  }

  adjustButtonPosition() {
    const nav = document.querySelector('.navbar')
    const button = this.buttonTarget || document.getElementById('drawer-toggle-btn')
    if (nav && button) {
      const navHeight = nav.offsetHeight
      button.style.top = `${navHeight / 2 - 20}px`
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observer = null
    this.init()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  init() {
    if (this.observer) this.observer.disconnect()

    const elements = this.element.querySelectorAll('.scale-in')
    if (elements.length === 0) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const images = entry.target.querySelectorAll('img')
          let imagesLoaded = 0

          if (images.length === 0) {
            setTimeout(() => entry.target.classList.add('scale-in-active'), 100)
          } else {
            images.forEach(img => {
              if (img.complete) {
                imagesLoaded++
              } else {
                const handle = () => {
                  imagesLoaded++
                  if (imagesLoaded === images.length) {
                    setTimeout(() => entry.target.classList.add('scale-in-active'), 100)
                  }
                  img.removeEventListener('load', handle)
                  img.removeEventListener('error', handle)
                }
                img.addEventListener('load', handle)
                img.addEventListener('error', handle)
              }
            })

            if (imagesLoaded === images.length) {
              setTimeout(() => entry.target.classList.add('scale-in-active'), 100)
            }
          }
        }
      })
    }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' })

    elements.forEach(el => this.observer.observe(el))
  }
}

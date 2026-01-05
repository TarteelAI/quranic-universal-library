import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["offcanvas"]
  static values = {
    open: Boolean
  }

  connect() {
    this.openValue = false
    this.setupClickOutside()
  }

  disconnect() {
    this.removeClickOutside()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    if (this.hasOffcanvasTarget) {
      this.offcanvasTarget.classList.remove('tw-hidden')
      this.offcanvasTarget.classList.add('tw-fixed', 'tw-top-0', 'tw-right-0', 'tw-h-full', 'tw-w-full', 'tw-max-w-md', 'tw-bg-white', 'tw-shadow-xl', 'tw-z-50', 'tw-transform', 'tw-transition-transform', 'tw-duration-300', 'tw-ease-in-out')
      document.body.style.overflow = 'hidden'
      
      const backdrop = document.createElement('div')
      backdrop.className = 'tw-fixed tw-inset-0 tw-bg-black tw-bg-opacity-50 tw-z-40 tw-transition-opacity tw-duration-300'
      backdrop.id = 'offcanvas-backdrop'
      backdrop.addEventListener('click', () => {
        this.openValue = false
      })
      document.body.appendChild(backdrop)
      
      setTimeout(() => {
        this.offcanvasTarget.style.transform = 'translateX(0)'
      }, 10)
    }
  }

  hide() {
    if (this.hasOffcanvasTarget) {
      this.offcanvasTarget.style.transform = 'translateX(100%)'
      
      const backdrop = document.getElementById('offcanvas-backdrop')
      if (backdrop) {
        backdrop.style.opacity = '0'
        setTimeout(() => {
          if (backdrop.parentNode) {
            backdrop.parentNode.removeChild(backdrop)
          }
        }, 300)
      }
      
      setTimeout(() => {
        this.offcanvasTarget.classList.add('tw-hidden')
        this.offcanvasTarget.classList.remove('tw-fixed', 'tw-top-0', 'tw-right-0', 'tw-h-full', 'tw-w-full', 'tw-max-w-md', 'tw-bg-white', 'tw-shadow-xl', 'tw-z-50', 'tw-transform', 'tw-transition-transform', 'tw-duration-300', 'tw-ease-in-out')
        document.body.style.overflow = ''
      }, 300)
    }
  }

  hideOnClick(event) {
    if (!this.element.contains(event.target) && !this.offcanvasTarget.contains(event.target)) {
      this.openValue = false
    }
  }

  setupClickOutside() {
    this.boundHideOnClick = this.hideOnClick.bind(this)
    document.addEventListener('click', this.boundHideOnClick)
  }

  removeClickOutside() {
    if (this.boundHideOnClick) {
      document.removeEventListener('click', this.boundHideOnClick)
    }
  }
}




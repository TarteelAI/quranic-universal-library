import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["offcanvas"]
  static values = {
    open: Boolean,
    target: String
  }

  connect() {
    this.openValue = false
    this.setupClickOutside()
  }

  disconnect() {
    this.removeClickOutside()
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  getTarget() {
    if (this.hasOffcanvasTarget) {
      return this.offcanvasTarget
    }

    if (this.hasTargetValue) {
      return document.querySelector(this.targetValue)
    }

    return null
  }

  show() {
    const target = this.getTarget()
    if (target) {
      target.classList.remove('tw-hidden')
      
      // Determine direction based on class
      const isLeft = target.classList.contains('tw-left-0')
      target.style.transform = isLeft ? 'translateX(-100%)' : 'translateX(100%)'

      // Force reflow
      target.offsetHeight

      target.classList.add('tw-fixed', 'tw-top-0', 'tw-h-full', 'tw-w-full', 'tw-max-w-md', 'tw-bg-white', 'tw-shadow-xl', 'tw-z-50', 'tw-transform', 'tw-transition-transform', 'tw-duration-300', 'tw-ease-in-out')
      
      setTimeout(() => {
        target.style.transform = 'translateX(0)'
      }, 10)
    }
  }

  hide() {
    const target = this.getTarget()
    if (target) {
      const isLeft = target.classList.contains('tw-left-0')
      target.style.transform = isLeft ? 'translateX(-100%)' : 'translateX(100%)'
      
      setTimeout(() => {
        target.classList.add('tw-hidden')
        target.classList.remove('tw-fixed', 'tw-top-0', 'tw-h-full', 'tw-w-full', 'tw-max-w-md', 'tw-bg-white', 'tw-shadow-xl', 'tw-z-50', 'tw-transform', 'tw-transition-transform', 'tw-duration-300', 'tw-ease-in-out')
      }, 300)
    }
  }

  hideOnClick(event) {
    const target = this.getTarget()
    if (target && !this.element.contains(event.target) && !target.contains(event.target)) {
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




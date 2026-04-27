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
      target.classList.remove('hidden')
      
      // Determine direction based on class
      const isLeft = target.classList.contains('left-0')
      target.style.transform = isLeft ? 'translateX(-100%)' : 'translateX(100%)'

      // Force reflow
      target.offsetHeight

      target.classList.add('fixed', 'top-0', 'h-full', 'w-full', 'max-w-md', 'bg-white', 'shadow-xl', 'z-50', 'transform', 'transition-transform', 'duration-300', 'ease-in-out')
      
      setTimeout(() => {
        target.style.transform = 'translateX(0)'
      }, 10)
    }
  }

  hide() {
    const target = this.getTarget()
    if (target) {
      const isLeft = target.classList.contains('left-0')
      target.style.transform = isLeft ? 'translateX(-100%)' : 'translateX(100%)'
      
      setTimeout(() => {
        target.classList.add('hidden')
        target.classList.remove('fixed', 'top-0', 'h-full', 'w-full', 'max-w-md', 'bg-white', 'shadow-xl', 'z-50', 'transform', 'transition-transform', 'duration-300', 'ease-in-out')
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




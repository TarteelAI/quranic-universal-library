import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
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
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('tw-hidden')
      this.menuTarget.classList.add('tw-block')
    }
    this.element.classList.add('tw-relative')
  }

  hide() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add('tw-hidden')
      this.menuTarget.classList.remove('tw-block')
    }
  }

  hideOnClick(event) {
    if (!this.element.contains(event.target)) {
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

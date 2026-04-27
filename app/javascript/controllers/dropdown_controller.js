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
    this.closeAllOtherDropdowns()
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('hidden')
      this.menuTarget.classList.add('block')
    }
    this.element.classList.add('relative')
  }

  closeAllOtherDropdowns() {
    const allDropdowns = document.querySelectorAll('[data-controller*="dropdown"]')
    allDropdowns.forEach(dropdownElement => {
      if (dropdownElement !== this.element) {
        try {
          const controller = this.application.getControllerForElementAndIdentifier(dropdownElement, 'dropdown')
          if (controller && controller.openValue) {
            controller.openValue = false
          }
        } catch (e) {
        }
      }
    })
  }

  hide() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add('hidden')
      this.menuTarget.classList.remove('block')
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

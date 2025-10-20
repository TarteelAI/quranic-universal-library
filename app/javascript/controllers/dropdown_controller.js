import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "icon"]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const menu = this.menuTarget
    const button = event.currentTarget
    
    if (menu.classList.contains("tw-hidden")) {
      menu.classList.remove("tw-hidden")
      button.setAttribute("aria-expanded", "true")
      if (this.hasIconTarget) this.iconTarget.style.transform = "rotate(180deg)"

      setTimeout(() => {
        document.addEventListener("click", this.clickOutsideHandler)
      }, 0)
    } else {
      this.close()
    }
  }

  close() {
    const menu = this.menuTarget
    const button = this.element.querySelector('[aria-expanded]')
    
    if (!menu.classList.contains("tw-hidden")) {
      menu.classList.add("tw-hidden")
      if (button) {
        button.setAttribute("aria-expanded", "false")
      }
      if (this.hasIconTarget) this.iconTarget.style.transform = "rotate(0deg)"
      document.removeEventListener("click", this.clickOutsideHandler)
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}


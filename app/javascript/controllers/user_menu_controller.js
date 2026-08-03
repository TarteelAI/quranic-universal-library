import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundCloseOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
  }

  close() {
    this.element.removeAttribute("open")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}

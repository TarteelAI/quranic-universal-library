import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resetHandler = this.reset.bind(this)
    window.addEventListener('resize', this.resetHandler)
  }

  disconnect() {
    window.removeEventListener('resize', this.resetHandler)
  }

  reset() {
    if (window.innerWidth >= 768) {
      const offcanvasElement = document.querySelector('.offcanvas.show');
      if (offcanvasElement) {
        const btnClose = offcanvasElement.querySelector('.btn-close');
        if (btnClose) {
          btnClose.click();
        }
      }
    }
  }
}

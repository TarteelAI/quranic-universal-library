import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    event.preventDefault()
    this.element.style.transition = 'opacity 0.15s linear';
    this.element.style.opacity = '0';
    setTimeout(() => this.element.remove(), 150);
  }
}


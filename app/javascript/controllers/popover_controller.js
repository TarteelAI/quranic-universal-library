import { Controller } from "@hotwired/stimulus"
import { Popover } from "bootstrap"

export default class extends Controller {
  connect() {
    this.popover = new Popover(this.element, {
      trigger: 'focus',
      html: true
    })
  }

  disconnect() {
    if (this.popover) {
      this.popover.dispose()
    }
  }
}

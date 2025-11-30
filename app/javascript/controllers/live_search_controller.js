import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "searchInput"]

  connect() {
    this.timeout = null
    this.debounceMs = 300
  }

  search() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.debounceMs)
  }

  submitForm() {
    this.formTarget.requestSubmit()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
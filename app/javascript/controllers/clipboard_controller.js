import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy() {
    const text = this.sourceTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.element.querySelectorAll("[data-clipboard-label]").forEach((label) => {
        const original = label.textContent
        label.textContent = "Copied!"
        setTimeout(() => { label.textContent = original }, 1200)
      })
    })
  }
}

import { Controller } from "@hotwired/stimulus"

// Copy buttons on the resource Docs tab. A button inside a `.docs-code`
// block copies that block's <code> text.
export default class extends Controller {
  async copy(event) {
    const button = event.currentTarget
    const code = button.closest(".docs-code")?.querySelector("code")
    if (!code) return

    const copied = await this.copyToClipboard(code.textContent)
    const original = button.dataset.originalLabel || button.textContent
    button.dataset.originalLabel = original
    button.textContent = copied ? "Copied" : "Copy failed"

    clearTimeout(button._copyTimer)
    button._copyTimer = setTimeout(() => { button.textContent = original }, 1200)
  }

  // The Clipboard API also rejects when the page isn't focused, so fall back
  // to the textarea trick.
  async copyToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        return true
      } catch (error) {
        // fall through
      }
    }

    const element = document.createElement("textarea")
    element.value = text
    element.style.position = "fixed"
    element.style.opacity = "0"
    document.body.appendChild(element)
    element.select()
    const copied = document.execCommand("copy")
    element.remove()
    return copied
  }
}

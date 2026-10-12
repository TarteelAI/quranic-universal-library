import { Controller } from "@hotwired/stimulus"

// Gallery for an SVG artwork resource: fetches each file from the CDN and
// inlines it, so the size and colour controls actually reach the artwork.
export default class extends Controller {
  static targets = ["grid", "search", "sizeSlider", "sizeValue", "colour", "count"]

  static values = {
    urls: Array
  }

  connect() {
    this.rendered = false
    this.searchTimer = null
    this.updateCount()
  }

  disconnect() {
    clearTimeout(this.searchTimer)
  }

  showGallery() {
    if (this.rendered) return
    this.rendered = true

    this.urlsValue.forEach((url) => this.gridTarget.appendChild(this.buildCard(url)))
    this.updateSize()
    this.updateColour()
  }

  buildCard(url) {
    const label = url.split("/").pop().replace(/\.svg$/, "")

    const card = document.createElement("button")
    card.type = "button"
    card.className = "svg-card"
    card.dataset.svgName = label.toLowerCase()
    card.dataset.svgUrl = url
    card.title = `Copy ${url}`
    card.addEventListener("click", () => this.copyUrl(card))

    const art = document.createElement("div")
    art.className = "svg-card-art"
    card.appendChild(art)

    const name = document.createElement("span")
    name.className = "svg-card-name"
    name.textContent = label
    card.appendChild(name)

    this.loadInto(art, url, label)

    return card
  }

  async loadInto(container, url, label) {
    try {
      const response = await fetch(url)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const markup = await response.text()
      const svg = new DOMParser().parseFromString(markup, "image/svg+xml").documentElement

      if (svg.nodeName.toLowerCase() !== "svg") throw new Error("not an SVG")

      // Let CSS drive the size; the viewBox keeps the aspect ratio.
      svg.removeAttribute("width")
      svg.removeAttribute("height")
      container.appendChild(svg)
    } catch (error) {
      container.textContent = "—"
      container.title = `Could not load ${label}: ${error.message}`
    }
  }

  filter() {
    clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => this.applyFilter(), 150)
  }

  applyFilter() {
    const term = (this.hasSearchTarget ? this.searchTarget.value : "").trim().toLowerCase()

    this.cards().forEach((card) => {
      card.hidden = term !== "" && !card.dataset.svgName.includes(term)
    })

    this.updateCount()
  }

  updateSize() {
    if (!this.hasSizeSliderTarget) return

    const size = Number(this.sizeSliderTarget.value)
    this.element.style.setProperty("--svg-card-height", `${size}px`)
    if (this.hasSizeValueTarget) this.sizeValueTarget.textContent = `${size}px`
  }

  updateColour() {
    if (!this.hasColourTarget) return

    this.element.style.setProperty("--svg-card-colour", this.colourTarget.value)
  }

  updateBackground(event) {
    this.element.style.setProperty("--svg-card-bg", event.target.value)
  }

  async copyUrl(card) {
    const copied = await this.copyToClipboard(card.dataset.svgUrl)
    if (copied) this.flash(card)
  }

  async copyCode(event) {
    const button = event.currentTarget
    const code = button.closest(".docs-code")?.querySelector("code")
    if (!code) return

    const copied = await this.copyToClipboard(code.textContent)
    const original = button.dataset.originalLabel || button.textContent
    button.dataset.originalLabel = original
    button.textContent = copied ? "Copied" : "Copy failed"

    clearTimeout(button._svgCopyTimer)
    button._svgCopyTimer = setTimeout(() => { button.textContent = original }, 1200)
  }

  flash(card) {
    card.classList.add("svg-card-copied")
    clearTimeout(card._svgCopyTimer)
    card._svgCopyTimer = setTimeout(() => card.classList.remove("svg-card-copied"), 900)
  }

  // The Clipboard API is not just missing on older browsers, it also rejects
  // when the page is not focused or the permission is denied — fall back to
  // the textarea trick in both cases.
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

    try {
      return document.execCommand("copy")
    } catch (error) {
      return false
    } finally {
      element.remove()
    }
  }

  cards() {
    return Array.from(this.gridTarget.querySelectorAll(".svg-card"))
  }

  updateCount() {
    if (!this.hasCountTarget) return

    const total = this.urlsValue.length
    const visible = this.rendered ? this.cards().filter((card) => !card.hidden).length : total
    this.countTarget.textContent = visible === total ? `${total} images` : `${visible} of ${total}`
  }
}

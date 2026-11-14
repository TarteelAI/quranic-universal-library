import { Controller } from "@hotwired/stimulus"

// Chip filters over cards (the Fix step's ayahs, the Align step's words), plus,
// where the view has one, a box that narrows the cards to one ayah ("76" or
// "2:76"). The chip and the box combine. With paramValue set ("ayah"), the box
// is filled from that URL parameter on load, so a shared link opens on the
// ayah it names.
export default class extends Controller {
  static targets = ["card", "chip", "ayahInput", "count"]
  static values = { param: String }

  connect() {
    this.current = "all"
    if (this.hasParamValue && this.paramValue && this.hasAyahInputTarget) {
      const value = new URLSearchParams(globalThis.location?.search || "").get(this.paramValue)
      if (value) {
        this.ayahInputTarget.value = value
        this.apply()
      }
    }
  }

  filter(event) {
    this.current = event.currentTarget.dataset.filter
    this.chipTargets.forEach((chip) => {
      const active = chip.dataset.filter === this.current
      chip.classList.toggle("bg-indigo-600", active)
      chip.classList.toggle("text-white", active)
      chip.classList.toggle("bg-gray-100", !active)
      chip.classList.toggle("text-gray-700", !active)
    })
    this.apply()
  }

  apply() {
    const ayah = this.hasAyahInputTarget ? this.ayahInputTarget.value.trim() : ""
    let shown = 0
    this.cardTargets.forEach((card) => {
      const keep = this.matches(card, this.current) && this.matchesAyah(card, ayah)
      card.classList.toggle("hidden", !keep)
      if (keep) shown++
    })
    if (this.hasCountTarget) {
      this.countTarget.textContent = (this.current === "all" && !ayah) ? "" : `${shown} shown`
    }
  }

  matches(card, value) {
    if (!value || value === "all") return true
    if (value === "exact") return card.dataset.exact === "true"
    return card.dataset[value] === "true"
  }

  // "76" matches the ayah number, "2:76" the key. Cards without an ayah (the
  // Align step's word rows) are never narrowed by it.
  matchesAyah(card, ayah) {
    if (!ayah || card.dataset.ayahKey === undefined) return true
    return ayah.includes(":") ? card.dataset.ayahKey === ayah : card.dataset.ayahNumber === ayah
  }
}

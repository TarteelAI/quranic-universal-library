import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "chip"]

  filter(event) {
    const value = event.currentTarget.dataset.filter
    this.cardTargets.forEach((card) => {
      card.classList.toggle("hidden", !this.matches(card, value))
    })
    this.chipTargets.forEach((chip) => {
      const active = chip.dataset.filter === value
      chip.classList.toggle("bg-indigo-600", active)
      chip.classList.toggle("text-white", active)
      chip.classList.toggle("bg-gray-100", !active)
      chip.classList.toggle("text-gray-700", !active)
    })
  }

  matches(card, value) {
    if (value === "all") return true
    if (value === "exact") return card.dataset.exact === "true"
    return card.dataset[value] === "true"
  }
}

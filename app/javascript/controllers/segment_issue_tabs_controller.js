import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "pane"]

  select(event) {
    const category = event.currentTarget.dataset.category

    this.paneTargets.forEach((pane) => {
      pane.classList.toggle("hidden", pane.dataset.category !== category)
    })

    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("bg-white", active)
      tab.classList.toggle("border-gray-300", active)
      tab.classList.toggle("text-gray-900", active)
      tab.classList.toggle("bg-gray-50", !active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-gray-500", !active)
    })
  }
}

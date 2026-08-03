import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "loader"]
  static classes = ["active", "inactive"]

  select(event) {
    this.tabTargets.forEach((tab) => {
      const selected = tab === event.currentTarget
      tab.classList.remove(...(selected ? this.inactiveClasses : this.activeClasses))
      tab.classList.add(...(selected ? this.activeClasses : this.inactiveClasses))
    })
  }

  showLoader() {
    if (this.hasLoaderTarget) this.loaderTarget.classList.remove("hidden")
  }

  hideLoader() {
    if (this.hasLoaderTarget) this.loaderTarget.classList.add("hidden")
  }
}

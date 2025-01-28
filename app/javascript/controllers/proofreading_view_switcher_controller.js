import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view"]

  showView(event) {
    const viewType = event.params.view
    this.viewTargets.forEach(view => {
      view.classList.toggle('active', view.dataset.viewType === viewType)
    })

    const buttons = this.element.querySelectorAll('.view-switcher-button')
    buttons.forEach(button => {
      button.classList.toggle('active', button.dataset.viewSwitcherViewParam === viewType)
    })
  }
}
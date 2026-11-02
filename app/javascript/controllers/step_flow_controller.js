import {Controller} from "@hotwired/stimulus";

// Clickable steps in the tool help, shows one step at a time.
// The markup comes from StepFlowHelper#step_flow.
export default class extends Controller {
  static targets = ["node", "panel"]

  connect() {
    this.select(0)
  }

  show(event) {
    this.select(event.params.index)
  }

  next() {
    this.select(Math.min(this.current + 1, this.panelTargets.length - 1))
  }

  previous() {
    this.select(Math.max(this.current - 1, 0))
  }

  select(index) {
    this.current = index
    this.panelTargets.forEach((panel, i) => panel.classList.toggle("hidden", i !== index))
    this.nodeTargets.forEach((node, i) => node.setAttribute("aria-selected", i === index))
  }
}

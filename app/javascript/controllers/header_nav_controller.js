import { Controller } from "@hotwired/stimulus"

const ACTIVE_NAV_CLASS = "nav-link--active"

const RESOURCES_PREFIX = "/resources"
const FAQ_PATH = "/faq"
const TOOLS_PATH = "/tools"
const CMS_PREFIX = "/cms"

export default class extends Controller {
  static targets = ["resources", "tools", "faq", "cms"]

  connect() {
    this.boundApply = () => this.apply()
    this.apply()
    document.addEventListener("turbo:load", this.boundApply)
    document.addEventListener("turbo:render", this.boundApply)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundApply)
    document.removeEventListener("turbo:render", this.boundApply)
  }

  apply() {
    const path = window.location.pathname
    this.clearNavStates()

    if (this.matchesResources(path)) {
      this.activateTargets(this.resourcesTargets)
    } else if (path === TOOLS_PATH) {
      this.activateTargets(this.toolsTargets)
    } else if (path === FAQ_PATH) {
      this.activateTargets(this.faqTargets)
    } else if (this.matchesCms(path)) {
      this.activateTargets(this.cmsTargets)
    }
  }

  matchesResources(path) {
    return path === RESOURCES_PREFIX || path.startsWith(`${RESOURCES_PREFIX}/`)
  }

  matchesCms(path) {
    return path.startsWith(CMS_PREFIX)
  }

  clearNavStates() {
    ;[
      ...this.resourcesTargets,
      ...this.toolsTargets,
      ...this.faqTargets,
      ...this.cmsTargets,
    ].forEach((el) => {
      el.classList.remove(ACTIVE_NAV_CLASS)
      el.removeAttribute("aria-current")
    })
  }

  activateTargets(elements) {
    elements.forEach((el) => {
      el.classList.add(ACTIVE_NAV_CLASS)
      el.setAttribute("aria-current", "page")
    })
  }
}

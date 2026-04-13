import { Controller } from "@hotwired/stimulus"

const ACTIVE_NAV_CLASS = "nav-link--active"

const RESOURCES_PREFIX = "/resources"
const FAQ_PATH = "/faq"
const CREDITS_PATH = "/credits"
const CMS_PREFIX = "/cms"

const TOOL_PATH_PREFIXES = [
  "/tools",
  "/mushaf_layouts",
  "/tajweed_words",
  "/morphology_phrases",
  "/surah_audio_files",
  "/ayah_audio_files",
  "/translation_proofreadings",
  "/tafsir_proofreadings",
  "/word_text_proofreadings",
  "/surah_infos",
  "/arabic_transliterations",
  "/word_translations",
  "/word_concordance_labels",
  "/morphology/dependency-graphs",
  "/community/chars_info",
  "/compare_ayah",
  "/quran_scripts_comparison",
  "/segments",
  "/compare-audio",
  "/ayah-boundaries",
].sort((a, b) => b.length - a.length)

export default class extends Controller {
  static targets = ["resources", "tools", "faq", "credits", "cms"]

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
    } else if (this.matchesTools(path)) {
      this.activateTargets(this.toolsTargets)
    } else if (path === FAQ_PATH) {
      this.activateTargets(this.faqTargets)
    } else if (path === CREDITS_PATH) {
      this.activateTargets(this.creditsTargets)
    } else if (this.matchesCms(path)) {
      this.activateTargets(this.cmsTargets)
    }
  }

  matchesResources(path) {
    return path === RESOURCES_PREFIX || path.startsWith(`${RESOURCES_PREFIX}/`)
  }

  matchesTools(path) {
    return TOOL_PATH_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`))
  }

  matchesCms(path) {
    return path.startsWith(CMS_PREFIX)
  }

  clearNavStates() {
    ;[
      ...this.resourcesTargets,
      ...this.toolsTargets,
      ...this.faqTargets,
      ...this.creditsTargets,
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

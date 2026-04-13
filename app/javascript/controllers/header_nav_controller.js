import { Controller } from "@hotwired/stimulus"

const DESKTOP_IDLE = "tw-text-black hover:tw-text-[#46ac7a] tw-transition-colors tw-hidden md:tw-flex"
const DESKTOP_ACTIVE = "tw-text-[#46ac7a] tw-font-semibold hover:tw-text-[#46ac7a] tw-transition-colors tw-hidden md:tw-flex"
const DRAWER_IDLE = "tw-text-black hover:tw-text-[#46ac7a] tw-transition-colors tw-text-lg"
const DRAWER_ACTIVE = "tw-text-[#46ac7a] tw-font-semibold hover:tw-text-[#46ac7a] tw-transition-colors tw-text-lg"
const LOGO_CLASS = "tw-text-black"
const CMS_IDLE = "btn-outline-pill tw-px-4 tw-py-1 md:tw-px-6 md:tw-py-2"
const CMS_ACTIVE = "btn-outline-pill tw-px-4 tw-py-1 md:tw-px-6 md:tw-py-2 tw-font-semibold tw-border-[#46ac7a] !tw-text-[#46ac7a] hover:!tw-bg-[#46ac7a]/10 hover:!tw-text-[#46ac7a] hover:!tw-border-[#46ac7a]"

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
  static targets = ["logo", "resources", "tools", "faq", "credits", "cms"]

  connect() {
    this.boundApply = () => this.apply()
    this.apply()
    document.addEventListener("turbo:load", this.boundApply)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundApply)
  }

  apply() {
    const path = window.location.pathname
    this.resetNavLinks()
    this.resetCms()
    this.resetLogo()

    if (this.matchesResources(path)) {
      this.activateTargets(this.resourcesTargets, "active")
    } else if (this.matchesTools(path)) {
      this.activateTargets(this.toolsTargets, "active")
    } else if (path === FAQ_PATH) {
      this.activateTargets(this.faqTargets, "active")
    } else if (path === CREDITS_PATH) {
      this.activateTargets(this.creditsTargets, "active")
    } else if (this.matchesCms(path)) {
      this.activateCms()
    }

    if (path === "/" || path === "") {
      this.logoTargets.forEach((el) => el.setAttribute("aria-current", "page"))
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

  resetNavLinks() {
    this.setTargetsVariant(this.resourcesTargets, "idle")
    this.setTargetsVariant(this.toolsTargets, "idle")
    this.setTargetsVariant(this.faqTargets, "idle")
    this.setTargetsVariant(this.creditsTargets, "idle")
  }

  setTargetsVariant(elements, mode) {
    elements.forEach((el) => {
      const drawer = el.dataset.variant === "drawer"
      el.className = this.classForLink(el, drawer, mode)
      el.removeAttribute("aria-current")
    })
  }

  activateTargets(elements, mode) {
    elements.forEach((el) => {
      const drawer = el.dataset.variant === "drawer"
      el.className = this.classForLink(el, drawer, mode)
      el.setAttribute("aria-current", "page")
    })
  }

  classForLink(el, drawer, mode) {
    const active = mode === "active"
    if (drawer) {
      return active ? DRAWER_ACTIVE : DRAWER_IDLE
    }
    return active ? DESKTOP_ACTIVE : DESKTOP_IDLE
  }

  resetCms() {
    if (!this.hasCmsTarget) return
    this.cmsTargets.forEach((el) => {
      el.className = CMS_IDLE
      el.removeAttribute("aria-current")
    })
  }

  activateCms() {
    this.cmsTargets.forEach((el) => {
      el.className = CMS_ACTIVE
      el.setAttribute("aria-current", "page")
    })
  }

  resetLogo() {
    if (!this.hasLogoTarget) return
    this.logoTargets.forEach((el) => {
      el.className = LOGO_CLASS
      el.removeAttribute("aria-current")
    })
  }
}

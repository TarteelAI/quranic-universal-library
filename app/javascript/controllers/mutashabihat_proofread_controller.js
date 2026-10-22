import {Controller} from "@hotwired/stimulus"

// Ayah proofreading page: hovering a phrase card highlights its words in
// the ayah, and hovering a word highlights the phrases it belongs to.
export default class extends Controller {
  static targets = ["sentinel", "sticky"]

  // The ayah text pins below the 75px site header. Once pinned it gets a
  // smaller font and a capped height (see .ayah-sticky.is-stuck).
  connect() {
    this.onScroll = this.updateStuck.bind(this)
    window.addEventListener("scroll", this.onScroll, {passive: true})
    this.updateStuck()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  updateStuck() {
    if (!this.hasSentinelTarget || !this.hasStickyTarget) return

    this.stickyTarget.classList.toggle("is-stuck", this.sentinelTarget.getBoundingClientRect().top < 76)
  }

  focusGroup(event) {
    this.focus([event.currentTarget.dataset.group])
  }

  focusWord(event) {
    this.focus(event.currentTarget.dataset.groups.split(" "))
  }

  focus(groups) {
    this.element.classList.add("is-focusing")

    this.element.querySelectorAll(".ayah-word.is-shared").forEach(word => {
      const match = word.dataset.groups.split(" ").some(g => groups.includes(g))
      word.classList.toggle("is-focused", match)
    })

    this.element.querySelectorAll(".phrase-group, .phrase-chip").forEach(card => {
      card.classList.toggle("is-focused", groups.includes(card.dataset.group))
    })
  }

  blur() {
    this.element.classList.remove("is-focusing")
    this.element.querySelectorAll(".is-focused").forEach(el => el.classList.remove("is-focused"))
  }
}

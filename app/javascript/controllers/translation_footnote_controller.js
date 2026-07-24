import {Controller} from "@hotwired/stimulus";

const HARDCODED_FOOTNOTES = {
  pl: "Plural — the Arabic address or verb is plural",
  sg: "Singular — the Arabic address or verb is singular",
  dl: "Dual — the Arabic address or verb is dual",
};

export default class extends Controller {
  connect() {
    this.inlineFootnotes()
  }

  inlineFootnotes() {
    const footnotes = this.element.querySelectorAll('sup')
    footnotes.forEach((dom) => {
      const footNote = dom.getAttribute('foot_note')
      const marker = (dom.textContent || '').trim().toLowerCase()

      dom.classList.add('footnote-marker')

      if (!footNote && HARDCODED_FOOTNOTES[marker]) {
        dom.classList.add('footnote-grammar')
        dom.setAttribute('title', HARDCODED_FOOTNOTES[marker])
        return
      }

      if (footNote) {
        $(dom).append(`(${footNote})`)
      }
    })
  }
}

import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.inlineFootnotes()
  }

  inlineFootnotes() {
    const footnotes = this.element.querySelectorAll('sup')
    footnotes.forEach((dom, _i ) => {
      $(dom).append(`(${dom.getAttribute('foot_note')})`)
    })
  }
}
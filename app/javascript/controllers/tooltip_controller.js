import {Controller} from "@hotwired/stimulus";

import {Tooltip} from "bootstrap";

export default class extends Controller {
  connect() {
    this.tip = new Tooltip(this.element, {html: true})
  }

  disconnect() {
    this.tip.hide()
    this.tip.dispose()
  }
}

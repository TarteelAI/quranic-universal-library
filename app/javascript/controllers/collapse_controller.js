import {Controller} from "@hotwired/stimulus";

import {Collapse} from "bootstrap";

export default class extends Controller {
  connect() {
    new Collapse(this.element, {toggle: true})
  }

  disconnect() {
  }
}

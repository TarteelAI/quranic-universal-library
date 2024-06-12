// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus";
import copyToClipboard from "copy-to-clipboard";

export default class extends Controller {
  connect() {
    $(this.element).on('click', () => this.copy());
  }

  disconnect() {}

  copy() {
    let text = $(this.element).data('text');
    copyToClipboard(text);

    $(this.element)
      .attr("title", "Copied")
      .tooltip("_fixTitle")
      .tooltip("show");

    $(this.element).on("hidden.bs.tooltip", () =>
      $(this.element).attr("title", "Copy").tooltip("_fixTitle")
    );
  }
}

// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus"
import select2 from "select2";
window.select2 = select2();

export default class extends Controller {
  connect() {
    let el = $(this.element);

    let options = { allowClear: true, placeholder: 'Select' };

    if (el.data("multiple")) {
      options["multiple"] = true;
    }

    if (el.data("tags")) {
      options["tags"] = true;

      options["createTag"] = newTag => {
        return {
          id: "new:" + newTag.term,
          text: newTag.term + " (create new)"
        };
      };
    }

    if (el.data("parent")) options["dropdownParent"] = $(el.data("parent"));

    options["templateResult"] = item => {
      return this.dropdownItemTemplate(item);
    };
    options["escapeMarkup"] = markup => markup;

    // Weird, had to expose select2 to window before using it.
    // Debug and fix this
    this.select = el.select2(options)
  }

  dropdownItemTemplate(item) {
    if (item.loading) return item.text;

    if (item.element && item.element.dataset) {
      let container = $(`
        <div class='22 select2-result ${item.element.dataset.class}'>
           <strong>${item.text}</strong>
          <div class='select2-result__title'>${item.element.dataset.description || ''}</div>
      </div>`);

      return container;
    } else {
      return item.text;
    }
  }

  disconnect() {
    const select = this.select.data("select2");
    if (select) select.destroy();
  }
}

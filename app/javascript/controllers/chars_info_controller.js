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
    const el = $(this.element);
    const fontSwitcher = el.find('select#change_font')
    this.el = el;

    if(fontSwitcher.length >0){
      fontSwitcher.on('change', this.changeFont.bind(this))
      fontSwitcher.trigger('change')
    }

    el.find('.font-size-slider').on('change', (event) => {
        const fontSize = event.target.value;

        el.find('.char').css('font-size', `${fontSize}px`)
        el.find('#font-size').html(`${fontSize}px`)
    })

    el.find('#toggle-issues').on('click', (event) => {
      el.find('.toggle').toggleClass('tw-hidden')
    })
  }

  disconnect() {}

  changeFont(e){
    const font = e.target.value;
    const char = this.el.find('.char');
    const txt = this.el.find('#text');

    char.removeClass();
    char.addClass(font).addClass('char')

    txt.removeClass()
    txt.addClass(font).addClass('text form-control')
  }

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

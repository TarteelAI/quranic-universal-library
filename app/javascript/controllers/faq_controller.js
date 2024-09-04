import { Controller } from "@hotwired/stimulus";
import copyToClipboard from "copy-to-clipboard";

export default class extends Controller {
  connect() {
    this.el = $(this.element);

    this.el.on('click', '.question',  (event) => {
      event.preventDefault();
      const target = $(event.target);
      target.closest('.item').toggleClass('active');
      target.closest('.item').find('.answer-wrapper').slideToggle(300);
    });
  }
}

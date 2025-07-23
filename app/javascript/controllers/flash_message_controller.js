// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus";
import toastr from "toastr";

toastr.options = {
  closeButton: true,
  debug: false,
  newestOnTop: true,
  progressBar: true,
  positionClass: "toast-top-right",
  preventDuplicates: true,
  onclick: null,
  showDuration: 300,
  hideDuration: 100,
  timeOut: 5000,
  extendedTimeOut: 0,
  showEasing: "swing",
  hideEasing: "linear",
  showMethod: "fadeIn",
  hideMethod: "fadeOut",
  tapToDismiss: true
};
export default class extends Controller {
  connect() {
    const { flashError, flashNotice } = this.element.dataset;

    flashError && toastr.error(flashError);
    flashNotice && toastr.success(flashNotice);
    setTimeout(() => {
      this.element.remove();
    }, 1000);
  }
}

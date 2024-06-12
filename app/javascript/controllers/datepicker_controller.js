// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus"
//import flatpickr from "flatpickr";

export default class extends Controller {
  connect() {
    this.pickerOptions = { disableMobile: true, dateFormat: "F d, Y" };
    const el = $(this.element);

    if (el.data("minDate")) {
      this.pickerOptions["minDate"] = el.data("minDate");
    }

    if (el.data("maxDate")) {
      this.pickerOptions["maxDate"] = el.data("maxDate");
    }

    if (el.data("mode")) {
      this.pickerOptions["mode"] = el.data("mode");
    }

    if ('time' == el.data("mode")) {
      this.pickerOptions["enableTime"] = true;
      this.pickerOptions["dateFormat"] = "h:i K";
      this.pickerOptions.time_24hr = false
    }

    this.picker = flatpickr(this.element, this.pickerOptions);
  }

  disconnect() {
    this.picker.destroy();
  }
}

// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.autoClose = this.element.dataset.autoClose;
    this.disableHistoryOnSubmit = this.autoClose || this.element.dataset.disableHistory;
    this.form = $(this.element);

    this.form.attr("novalidate", "novalidate");
    var that = this;

    this.form.find("[type='submit']").on("click", event => {
      if (this.form.hasClass("skip-validation")) return true;

      return that.jsValidate(event);
    });

    this.form.on("submit", event => {
      return that.jsValidate(event);
    });

    this.form.on("turbo:submit-start", this.disableFields.bind(this))
    this.form.on("turbo:submit-end", this.enableFields.bind(this))


    this.form.on("turbo:submit-end", (event, xhr, s) => {
      let form = event.target;
      const success = event.detail.success;

      if (success) {
        form.reset();
        form.classList.remove("was-validated");

        if (this.autoClose) {
          $(that.form)
            .closest(".modal")
            .modal("hide");
        } else if(!this.disableHistoryOnSubmit){
          history.pushState(
            {},
            "",
            event.detail.fetchResponse.response.url
          );
        }
      } else {
        $(form)
          .find("#form-error-wrapper div")
          .addClass("alert alert-danger")
          .removeClass("d-none");
      }

      return true;
    });

    this.form.on("ajax:error", event => {
      $(event.target)
        .find("#form-error-wrapper div")
        .html("Sorry, something went wrong. Error: Interval server error.")
        .addClass("alert alert-danger")
        .removeClass("d-none");
    });
  }

  jsValidate(event) {
    this.removeValidations();
    if (!this.form.hasClass("was-validated"))
      this.form.addClass("was-validated");

    if (this.form[0].checkValidity() === false) {
      event.preventDefault();
      event.stopPropagation();
      event.currentTarget.reportValidity();

      return false;
    } else {
      this.form.trigger("dirty:clear");
      $(event.currentTarget).addClass("validated");
      return true;
    }
  }

  disableFields(event) {
    const target = event.target;

    for (const field of target.elements) {
      field.disabled = true
    }
  }

  enableFields(event) {
    const target = event.target;

    for (const field of target.elements) {
      field.disabled = false
    }
  }

  removeValidations(dom){
    $("#errors-close-btn").click()
  }

  disconnect() {
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
   this.el = $(this.element);

   const ayahWords = this.el.find("[data-location]");

    ayahWords.on("mouseenter", (event) => {
      const location = $(event.target).data("location");
      $(`[data-location='${location}']`).addClass("border-highlighted");
    })

    ayahWords.on("mouseleave", (event) => {
      const location = $(event.target).data("location");
      $(`[data-location='${location}']`).removeClass("border-highlighted");
    })
  }
}

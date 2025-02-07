import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.el.find("[data-view]").on("click", this.showView.bind(this));
  }

  showView(event) {
    const viewType = event.currentTarget.dataset.view;
    this.el.find("[data-view]").removeClass("active");
    this.el.find("[data-view-type]").removeClass("active");

    this.el.find(`[data-view=${viewType}]`).addClass("active");
    this.el.find(`[data-view-type=${viewType}]`).addClass("active");
  }
}
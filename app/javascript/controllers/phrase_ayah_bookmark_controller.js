// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import {
  Controller
} from "@hotwired/stimulus"

import {
  Modal
} from "bootstrap";
import LocalStore from "../utils/LocalStore";

export default class extends Controller {
  connect() {
    this.store = new LocalStore();

    $(this.element).on("click", e => {
      this.loadModal(e);
    });
  }

  loadModal(e) {
    var that = this;
    e.preventDefault();
    e.stopImmediatePropagation();

    this.createModel();
    $("#ajax-modal").on("hidden.bs.modal", function (e) {
      $("#ajax-modal")
        .empty()
        .remove();
    });

    this.renderBookmarks();
  }

  renderBookmarks(){
    this.bookmarks = JSON.parse(this.store.get('bookmarks') || "{}")
    const modalBody = $("#ajax-modal .modal-body")
    modalBody.empty();
    Object.keys(this.bookmarks).forEach((key) => {
      modalBody.append(`<div class="row"><div class="col-12 border p-2 mb-2">${key}</div></div>`)
    })

    if(Object.keys(this.bookmarks).length === 0 )
      modalBody.append("You have not bookmarked any ayah.")
  }

  createModel(classes) {
    if ($("#ajax-modal").length > 0) {
      $("#ajax-modal").remove();
      $(".modal-backdrop").remove();
    }

    let modal = `<div class="modal fade" id="ajax-modal" aria-hidden="true" tabIndex="-1">
      <div class="modal-dialog modal-dialog-centered}">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="title">Bookmarks</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div id="modal-body">
          <div class="modal-body">
            Loading
          </div>
          </div>
        </div>
      </div>
    </div>`;

    $(modal).appendTo("body");

    this.modal = new Modal('#ajax-modal');
    this.modal.show();
  }
}
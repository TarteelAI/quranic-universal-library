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

// Bootstrap Modal removed - using custom bootstrap-modal controller instead
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
    const modalBody = $("#ajax-modal .tw-p-6")
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

    let modal = `<div class="tw-fixed tw-inset-0 tw-z-50 tw-overflow-y-auto tw-hidden" id="ajax-modal" aria-hidden="true" tabIndex="-1">
      <div class="tw-relative tw-w-auto tw-mx-auto tw-my-8 tw-max-w-lg">
        <div class="tw-relative tw-bg-white tw-rounded-lg tw-shadow-xl tw-overflow-hidden">
          <div class="tw-flex tw-items-center tw-justify-between tw-p-6 tw-border-b tw-border-gray-200">
            <h5 class="tw-text-lg tw-font-semibold tw-text-gray-900" id="title">Bookmarks</h5>
            <button type="button" class="tw-p-1 tw-rounded tw-text-gray-400 hover:tw-text-gray-600 hover:tw-bg-gray-200" aria-label="Close">
              <svg class="tw-w-4 tw-h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
            </button>
          </div>
          <div id="modal-body">
          <div class="tw-p-6">
            Loading
          </div>
          </div>
        </div>
      </div>
    </div>`;

    $(modal).appendTo("body");

    // Use custom modal controller instead of Bootstrap Modal
    const modalElement = document.getElementById('ajax-modal');
    modalElement.setAttribute('data-controller', 'bootstrap-modal');
    modalElement.setAttribute('data-bootstrap-modal-target-value', '#ajax-modal');
    
    // Trigger the modal to show
    const modalController = this.application.getControllerForElementAndIdentifier(modalElement, 'bootstrap-modal');
    if (modalController) {
      modalController.openModal(modalElement);
    }
  }
}
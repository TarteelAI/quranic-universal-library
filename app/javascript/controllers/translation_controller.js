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

export default class extends Controller {
    connect() {
        const draft = this.element.getAttribute("draft");

        $(this.element).on("click", "sup", e => {
            e.preventDefault();
            const target = e.target;

            this.loadModal(target.getAttribute("foot_note"), draft);
        });
    }

    loadModal(id, isDraft) {
        var that = this;

        let url = `/foot_notes/${id}?draft=${isDraft}`;
        this.createModel('translation');
        $("#ajax-modal").show()

        $("#ajax-modal").on("hidden.bs.modal", function (e) {
            $("#ajax-modal")
                .empty()
                .remove();
        });

        fetch(url).then(response => response.text()).then(content => {
            const response = $("<div>").html(content);
            this.setContent(response.find("#title").html(), response.find("#body").html())
        }).catch(err => {
            if (401 == err.status) {
                that.dialog.find(".tw-p-6").html(
                    `<div class='tw-w-full tw-text-center tw-p-5'> <h2>${err.responseText}</h2>
              <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="tw-bg-blue-600 tw-text-white hover:tw-bg-blue-700 tw-px-4 tw-py-2 tw-rounded-md">Login</a></p></div>`
                );
            }
        })
    }

    setContent(title, body) {
        const el = this.modal._element;
        el.querySelector('#title').innerHTML = title;
        el.querySelector('#modal-body').innerHTML = body;
    }

    createModel(classes) {
        if ($("#ajax-modal").length > 0) {
            $("#ajax-modal").remove();
            $(".modal-backdrop").remove();
        }

        let modal = `<div class="tw-fixed tw-inset-0 tw-z-50 tw-overflow-y-auto tw-hidden" id="ajax-modal" aria-hidden="true" tabIndex="-1">
      <div class="tw-relative tw-w-auto tw-mx-auto tw-my-8 tw-max-w-lg ${classes}">
        <div class="tw-relative tw-bg-white tw-rounded-lg tw-shadow-xl tw-overflow-hidden">
          <div class="tw-flex tw-items-center tw-justify-between tw-p-6 tw-border-b tw-border-gray-200">
            <h5 class="tw-text-lg tw-font-semibold tw-text-gray-900" id="title">Loading</h5>
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
        
        document.getElementById('ajax-modal').addEventListener("hidden.bs.modal", (e) => {
            $("#ajax-modal")
                .empty()
                .remove();
        });
    }
}
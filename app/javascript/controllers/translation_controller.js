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
                that.dialog.find(".modal-body").html(
                    `<div class='col text-center p-5'> <h2>${err.responseText}</h2>
              <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="btn btn-primary">Login</a></p></div>`
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

        let modal = `<div class="modal fade" id="ajax-modal" aria-hidden="true" tabIndex="-1">
      <div class="modal-dialog modal-dialog-centered ${classes}">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="title">Loading</h5>
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
        document.getElementById('ajax-modal').addEventListener("hidden.bs.modal", (e) => {
            $("#ajax-modal")
                .empty()
                .remove();
        });

        this.modal.show();
    }
}
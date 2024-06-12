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
    $(this.element).on("click", e => {
      if ($(e.target).hasClass("disable-loading")) return;

      this.loadModal(e);
    });
  }

  loadModal(e) {
    var that = this;
    e.preventDefault();
    e.stopImmediatePropagation();
    $(".round-card.popup").remove();

    let target = $(e.currentTarget);
    let url = target.data("url");
    let classes = target.data("class");
    this.createModel(classes);
    $("#ajax-modal").show()

    $("#ajax-modal").on("hidden.bs.modal", function (e) {
      $("#ajax-modal")
        .empty()
        .remove();
    });

    if (url) {
      fetch(url).then(response => response.text()).then(content => {
        const response = $("<div>").html(content);
        this.setContent(response.find("#title").html(), response.find("#body").html())
      }).catch(err => {
        if (401 == err.status) {
          that.dialog.find(".modal-body").html(
            `<div class='col text-center p-5'> <h2>${err.responseText}</h2>
              <p><a href="/users/sign_in?return_to=${location.pathname}" class="btn btn-primary">Login</a></p></div>`
          );
        }
      })
    } else {
      this.setContent(target.data("title"), `<div class="modal-body">${target.data("content")}</div>`)
    }
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
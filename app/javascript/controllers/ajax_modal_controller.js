// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus";

// Custom modal implementation to replace Bootstrap Modal
class CustomModal {
  constructor(element) {
    this.element =
      typeof element === "string" ? document.querySelector(element) : element;
    this._element = this.element;
    this.isShown = false;
  }

  show() {
    if (this.isShown) return;

    this.isShown = true;
    document.body.classList.add("modal-open");
    this.element.style.display = "block";
    this.element.classList.add("show");

    // Create backdrop
    this.backdrop = document.createElement("div");
    this.backdrop.className = "modal-backdrop fade show";
    document.body.appendChild(this.backdrop);

    // Add click handler to backdrop
    this.backdrop.addEventListener("click", () => this.hide());

    // Add escape key handler
    this.escapeKeyHandler = (e) => {
      if (e.key === "Escape") this.hide();
    };
    document.addEventListener("keydown", this.escapeKeyHandler);

    // Add close button handlers
    const closeButtons = this.element.querySelectorAll(
      '[data-bs-dismiss="modal"], .btn-close',
    );
    closeButtons.forEach((btn) => {
      btn.addEventListener("click", () => this.hide());
    });
  }

  hide() {
    if (!this.isShown) return;

    this.isShown = false;
    document.body.classList.remove("modal-open");
    this.element.style.display = "none";
    this.element.classList.remove("show");

    // Remove backdrop
    if (this.backdrop) {
      this.backdrop.remove();
      this.backdrop = null;
    }

    // Remove escape key handler
    if (this.escapeKeyHandler) {
      document.removeEventListener("keydown", this.escapeKeyHandler);
      this.escapeKeyHandler = null;
    }

    // Trigger hidden event
    const event = new CustomEvent("hidden.bs.modal");
    this.element.dispatchEvent(event);
  }
}

export default class extends Controller {
  connect() {
    $(this.element).on("click", (e) => {
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
    const url = target.data("url");
    const { useTurbo, cssClass } = e.currentTarget.dataset;

    this.createModel(cssClass);
    $("#ajax-modal").show();

    // Event handler will be added when creating the modal

    if (url) {
      const options = {
        method: "GET",
      };

      if (useTurbo) {
        options.headers = {
          Accept: "text/vnd.turbo-stream.html",
        };
      }
      fetch(url, options)
        .then((response) => response.text())
        .then((content) => {
          this.setResponse(content, useTurbo);
        })
        .catch((err) => {
          if (401 == err.status) {
            that.dialog.find(".modal-body").html(
              `<div class='col text-center p-5'> <h2>${err.responseText}</h2>
              <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="btn btn-primary">Login</a></p></div>`,
            );
          }
        });
    } else {
      this.setContent(
        target.data("title"),
        `<div class="modal-body">${target.data("content")}</div>`,
      );
    }
  }

  setContent(title, body) {
    const el = this.modal._element;
    el.querySelector("#title").innerHTML = title;
    el.querySelector("#modal-body").innerHTML = body;
  }

  setResponse(content, useTurbo) {
    if (useTurbo) {
      const el = $(this.modal._element);
      el.find("#modal-content").html(content);
      //Turbo.renderStreamMessage(content)
    } else {
      const response = $("<div>").html(content);
      this.setContent(
        response.find("#title").html(),
        response.find("#body").html(),
      );
    }
  }

  createModel(classes) {
    if ($("#ajax-modal").length > 0) {
      $("#ajax-modal").remove();
      $(".modal-backdrop").remove();
    }

    let modal = `<div class="modal fade" id="ajax-modal" aria-hidden="true" tabIndex="-1">
      <div class="modal-dialog modal-dialog-centered ${classes}">
        <div class="modal-content" id="modal-content">
          <div class="modal-header" id="modal-header">
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

    this.modal = new CustomModal("#ajax-modal");
    document
      .getElementById("ajax-modal")
      .addEventListener("hidden.bs.modal", (e) => {
        $("#ajax-modal").empty().remove();
      });

    this.modal.show();
  }
}

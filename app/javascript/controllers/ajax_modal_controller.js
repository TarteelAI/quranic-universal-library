// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "closeButton"];
  connect() {
    this.element.addEventListener("click", (e) => {
      if (e.target.closest('.disable-loading')) return;
      this.loadModal(e);
    });
  }
  
  // Handle escape key to close modal
  handleKeyDown(e) {
    if (e.key === 'Escape') {
      this.close();
    }
  }
  
  // Close modal method
  close() {
    const modal = document.getElementById('ajax-modal');
    if (modal) {
      // Remove event listeners
      document.removeEventListener('keydown', this.boundKeyDown);
      // Remove modal
      modal.remove();
    }
  }

  loadModal(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    
    // Remove any existing popups
    document.querySelectorAll(".round-card.popup").forEach(el => el.remove());

    const target = e.currentTarget;
    const url = target.dataset.url;
    const { useTurbo, cssClass } = target.dataset;

    this.createModel(cssClass);

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
            that.dialog.find(".tw-p-6").html(
              `<div class='tw-w-full tw-text-center tw-p-5'> <h2>${err.responseText}</h2>
              <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="tw-bg-blue-600 tw-text-white hover:tw-bg-blue-700 tw-px-4 tw-py-2 tw-rounded-md">Login</a></p></div>`,
            );
          }
        });
    } else {
      this.setContent(
        target.data("title"),
        `<div class="tw-p-6">${target.data("content")}</div>`,
      );
    }
  }

  setContent(title, body) {
    const modal = document.getElementById('ajax-modal');
    if (modal) {
      const titleEl = modal.querySelector("#title");
      const bodyEl = modal.querySelector("#modal-body");
      
      if (titleEl) titleEl.textContent = title;
      if (bodyEl) bodyEl.innerHTML = body;
    }
  }

  setResponse(content, useTurbo) {
    if (useTurbo) {
      const modal = document.getElementById('ajax-modal');
      if (modal) {
        const contentEl = modal.querySelector("#modal-content");
        if (contentEl) contentEl.innerHTML = content;
      }
      // Turbo.renderStreamMessage(content)
    } else {
      const parser = new DOMParser();
      const doc = parser.parseFromString(content, 'text/html');
      const title = doc.querySelector('#title')?.innerHTML || '';
      const body = doc.querySelector('#body')?.innerHTML || '';
      this.setContent(title, body);
    }
  }

  createModel(classes) {
    // Remove any existing modals
    const existingModal = document.getElementById('ajax-modal');
    if (existingModal) {
      existingModal.remove();
    }

    // Create modal HTML
    const modal = `
      <div class="tw-fixed tw-inset-0 tw-z-50 tw-overflow-y-auto" id="ajax-modal">
        <div class="tw-fixed tw-inset-0 tw-bg-black/50" data-action="click->ajax-modal#close"></div>
        <div class="tw-relative tw-w-auto tw-mx-auto tw-my-8 tw-max-w-lg ${classes}">
          <div class="tw-relative tw-bg-white tw-rounded-lg tw-shadow-xl tw-overflow-hidden">
            <div class="tw-flex tw-items-center tw-justify-between tw-p-6 tw-border-b tw-border-gray-200">
              <h5 class="tw-text-lg tw-font-semibold tw-text-gray-900" id="title">Loading</h5>
              <button type="button" 
                      class="tw-p-1 tw-rounded tw-text-gray-400 hover:tw-text-gray-600 hover:tw-bg-gray-200" 
                      data-action="click->ajax-modal#close"
                      aria-label="Close">
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
      </div>
    `;

    // Add modal to the page
    document.body.insertAdjacentHTML('beforeend', modal);
    
    // Show the modal
    const modalElement = document.getElementById('ajax-modal');
    modalElement.classList.remove('tw-hidden');
    
    // Add escape key handler
    this.boundKeyDown = this.handleKeyDown.bind(this);
    document.addEventListener('keydown', this.boundKeyDown);
  }
}

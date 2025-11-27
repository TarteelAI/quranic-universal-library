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
    const url = target.data('url')
    const {useTurbo, cssClass} = e.currentTarget.dataset;

    this.createModel(cssClass);
    this.show();

    if (url) {
      const options = {
        method: 'GET',
      }

      if (useTurbo) {
        options.headers = {
          Accept: "text/vnd.turbo-stream.html"
        }
      }
      fetch(url, options).then(response => {
        if (!response.ok && response.status === 401) {
          throw { status: 401, responseText: 'Unauthorized' };
        }
        return response.text();
      }).then(content => {
        this.setResponse(content, useTurbo)
      }).catch(err => {
        if (401 == err.status) {
          const modalBody = document.getElementById('modal-body');
          if (modalBody) {
            modalBody.innerHTML = `
              <div class='tw-text-center tw-p-5'> 
                <h2>${err.responseText || 'Unauthorized'}</h2>
                <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="tw-btn tw-btn-primary">Login</a></p>
              </div>`;
          }
        }
      })
    } else {
      this.setContent(target.data("title"), `<div class="tw-p-4">${target.data("content")}</div>`)
    }
  }

  setContent(title, body) {
    const el = document.getElementById('ajax-modal');
    if (el) {
      const titleEl = el.querySelector('#title');
      const bodyEl = el.querySelector('#modal-body');
      if (titleEl) titleEl.innerHTML = title;
      if (bodyEl) bodyEl.innerHTML = body;
    }
  }

  setResponse(content, useTurbo) {
    const el = document.getElementById('ajax-modal');
    if (!el) return;

    if (useTurbo) {
      const modalContent = el.querySelector('#modal-content');
      if (modalContent) {
        modalContent.innerHTML = content;
      }
    } else {
      const response = $("<div>").html(content);
      this.setContent(response.find("#title").html(), response.find("#body").html())
    }
  }

  createModel(classes) {
    const existingModal = document.getElementById('ajax-modal');
    const existingBackdrop = document.getElementById('ajax-modal-backdrop');
    if (existingModal) existingModal.remove();
    if (existingBackdrop) existingBackdrop.remove();

    let sizeClasses = 'tw-max-w-md';
    if (classes) {
      if (classes.includes('modal-lg')) {
        sizeClasses = 'tw-max-w-3xl';
      } else if (classes.includes('modal-xl')) {
        sizeClasses = 'tw-max-w-6xl';
      } else if (classes.includes('modal-sm')) {
        sizeClasses = 'tw-max-w-sm';
      }
    }

    const backdrop = document.createElement('div');
    backdrop.id = 'ajax-modal-backdrop';
    backdrop.className = 'tw-fixed tw-inset-0 tw-bg-black tw-bg-opacity-50 tw-transition-opacity tw-duration-300 tw-opacity-0 tw-z-40';
    backdrop.addEventListener('click', () => this.hide());
    document.body.appendChild(backdrop);

    const modal = document.createElement('div');
    modal.id = 'ajax-modal';
    modal.className = 'tw-fixed tw-inset-0 tw-z-50 tw-overflow-y-auto tw-opacity-0 tw-transition-opacity tw-duration-300';
    modal.setAttribute('aria-hidden', 'true');
    modal.setAttribute('tabIndex', '-1');
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    
    modal.innerHTML = `
      <div class="tw-flex tw-min-h-full tw-items-center tw-justify-center tw-p-4">
        <div class="tw-relative tw-w-full ${sizeClasses} tw-transform tw-transition-all tw-duration-300 tw-scale-95">
          <div class="tw-bg-white tw-rounded-lg tw-shadow-xl tw-overflow-hidden" id="modal-content">
            <div class="tw-flex tw-items-center tw-justify-between tw-px-6 tw-py-4 tw-border-b tw-border-gray-200" id="modal-header">
              <h5 class="tw-text-lg tw-font-semibold tw-text-gray-900 tw-m-0" id="title">Loading</h5>
              <button type="button" class="tw-text-gray-400 hover:tw-text-gray-600 tw-transition-colors tw-p-1" aria-label="Close" id="modal-close-btn">
                <svg class="tw-w-6 tw-h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            <div id="modal-body" class="tw-px-2">
              <div class="tw-p-4">
                Loading
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    this.modalElement = modal;
    this.backdropElement = backdrop;

    const closeBtn = modal.querySelector('#modal-close-btn');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => this.hide());
    }

    this.escapeHandler = (e) => {
      if (e.key === 'Escape') {
        this.hide();
      }
    };
    document.addEventListener('keydown', this.escapeHandler);

    this.closeEventHandler = () => {
      this.hide();
    };
    document.addEventListener('ajax-modal:close', this.closeEventHandler);

    document.body.style.overflow = 'hidden';

    modal.addEventListener('click', (e) => {
      const target = e.target.closest('[data-bs-dismiss="modal"]');
      if (target) {
        e.preventDefault();
        this.hide();
        return;
      }
      
      const modalContent = modal.querySelector('#modal-content');
      if (modalContent && !modalContent.contains(e.target)) {
        this.hide();
      }
    });
  }

  show() {
    requestAnimationFrame(() => {
      if (this.backdropElement) {
        this.backdropElement.classList.remove('tw-opacity-0');
        this.backdropElement.classList.add('tw-opacity-100');
      }
      if (this.modalElement) {
        this.modalElement.classList.remove('tw-opacity-0');
        this.modalElement.classList.add('tw-opacity-100');
        const dialog = this.modalElement.querySelector('.tw-scale-95');
        if (dialog) {
          dialog.classList.remove('tw-scale-95');
          dialog.classList.add('tw-scale-100');
        }
      }
    });
  }

  hide() {
    if (this.backdropElement) {
      this.backdropElement.classList.remove('tw-opacity-100');
      this.backdropElement.classList.add('tw-opacity-0');
    }
    if (this.modalElement) {
      this.modalElement.classList.remove('tw-opacity-100');
      this.modalElement.classList.add('tw-opacity-0');
      const dialog = this.modalElement.querySelector('.tw-scale-100');
      if (dialog) {
        dialog.classList.remove('tw-scale-100');
        dialog.classList.add('tw-scale-95');
      }
    }

    setTimeout(() => {
      if (this.modalElement) {
        this.modalElement.remove();
        this.modalElement = null;
      }
      if (this.backdropElement) {
        this.backdropElement.remove();
        this.backdropElement = null;
      }
      if (this.escapeHandler) {
        document.removeEventListener('keydown', this.escapeHandler);
        this.escapeHandler = null;
      }
      if (this.closeEventHandler) {
        document.removeEventListener('ajax-modal:close', this.closeEventHandler);
        this.closeEventHandler = null;
      }
      document.body.style.overflow = '';
    }, 300);
  }
}
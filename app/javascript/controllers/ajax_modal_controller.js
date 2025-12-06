import { Controller } from "@hotwired/stimulus";

export default class AjaxModalController extends Controller {
  connect() {
    $(this.element).on("click", e => {
      if ($(e.target).hasClass("disable-loading")) return;
      this.loadModal(e);
    });
  }

  loadModal(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    $(".round-card.popup").remove();

    const target = $(e.currentTarget);
    const url = target.data('url');
    const { useTurbo, cssClass } = e.currentTarget.dataset;

    this.createModal(cssClass);
    this.show();

    if (url) {
      const options = {
        method: 'GET',
      };

      if (useTurbo) {
        options.headers = {
          Accept: "text/vnd.turbo-stream.html"
        };
      }

      fetch(url, options)
        .then(response => {
          if (!response.ok && response.status === 401) {
            throw { status: 401, responseText: 'Unauthorized' };
          }
          return response.text();
        })
        .then(content => {
          this.setResponse(content, useTurbo);
        })
        .catch(err => {
          if (401 == err.status) {
            const modalBody = document.getElementById('ajax-modal-body');
            if (modalBody) {
              modalBody.innerHTML = `
                <div class='tw-text-center tw-p-5'> 
                  <h2>${err.responseText || 'Unauthorized'}</h2>
                  <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="tw-btn tw-btn-primary">Login</a></p>
                </div>`;
            }
          }
        });
    } else {
      this.setContent(target.data("title"), `<div class="tw-p-4">${target.data("content")}</div>`);
    }
  }

  setContent(title, body) {
    const modal = document.getElementById('ajax-modal');
    if (modal) {
      const titleEl = modal.querySelector('#ajax-modal-title');
      const bodyEl = modal.querySelector('#ajax-modal-body');
      if (titleEl) titleEl.textContent = title || '';
      if (bodyEl) bodyEl.innerHTML = body || '';
    }
  }

  setResponse(content, useTurbo) {
    const modal = document.getElementById('ajax-modal');
    if (!modal) return;

    if (useTurbo) {
      const modalBody = modal.querySelector('#ajax-modal-body');
      if (modalBody) {
        modalBody.innerHTML = content;
      }
    } else {
      const response = $("<div>").html(content);
      this.setContent(response.find("#title").html(), response.find("#body").html());
    }
  }

  createModal(classes) {
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

    const modal = document.createElement('div');
    modal.id = 'ajax-modal';
    modal.className = 'tw-fixed tw-inset-0 tw-z-50 tw-overflow-y-auto tw-overflow-x-hidden tw-flex tw-items-center tw-justify-center tw-w-full';
    modal.setAttribute('tabindex', '-1');
    modal.setAttribute('aria-hidden', 'false');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('role', 'dialog');

    modal.innerHTML = `
      <div class="tw-relative tw-p-4 tw-w-full ${sizeClasses} tw-max-h-full">
        <div class="tw-relative tw-bg-white tw-rounded-lg tw-shadow">
          <div class="tw-flex tw-items-center tw-justify-between tw-p-4 md:tw-p-5 tw-border-b tw-rounded-t tw-border-gray-200">
            <h3 class="tw-text-lg tw-font-semibold tw-text-gray-900 tw-m-0" id="ajax-modal-title">
              Loading
            </h3>
            <button type="button" class="tw-text-gray-400 tw-bg-transparent hover:tw-bg-gray-200 hover:tw-text-gray-900 tw-rounded-lg tw-text-sm tw-w-8 tw-h-8 tw-ms-auto tw-inline-flex tw-justify-center tw-items-center" aria-label="Close" id="ajax-modal-close">
              <svg class="tw-w-3 tw-h-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14">
                <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"/>
              </svg>
              <span class="tw-sr-only">Close modal</span>
            </button>
          </div>
          <div class="tw-p-4 md:tw-p-5 tw-space-y-4" id="ajax-modal-body">
            <div class="tw-p-4">Loading</div>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(backdrop);
    document.body.appendChild(modal);

    this.modalElement = modal;
    this.backdropElement = backdrop;

    const closeBtn = modal.querySelector('#ajax-modal-close');
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
  }

  show() {
    if (this.modalElement) {
      this.modalElement.style.display = 'flex';
    }
    if (this.backdropElement) {
      this.backdropElement.style.display = 'block';
      requestAnimationFrame(() => {
        if (this.backdropElement) {
          this.backdropElement.style.opacity = '1';
        }
      });
    }
  }

  hide() {
    if (this.backdropElement) {
      this.backdropElement.style.opacity = '0';
    }

    setTimeout(() => {
      if (this.modalElement && this.modalElement.parentNode) {
        this.modalElement.remove();
        this.modalElement = null;
      }
      if (this.backdropElement && this.backdropElement.parentNode) {
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

  disconnect() {
    this.hide();
  }
}

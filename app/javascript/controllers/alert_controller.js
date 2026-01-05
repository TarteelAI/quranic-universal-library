import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.add('tw-my-5');

    if (!this.element.querySelector('[data-action*="alert#close"]')) {
      this.element.classList.add('tw-relative');

      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'tw-absolute tw-top-2 tw-right-2 tw-text-gray-400 tw-bg-transparent hover:tw-bg-gray-200 hover:tw-text-gray-900 tw-rounded-lg tw-text-sm tw-p-1.5 tw-ml-auto tw-inline-flex tw-items-center';
      button.dataset.action = 'alert#close';
      button.innerHTML = `
        <svg class="tw-w-5 tw-h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
          <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
        </svg>
      `;
      this.element.appendChild(button);
    }
  }

  close(event) {
    event.preventDefault()
    this.element.style.transition = 'opacity 0.15s linear';
    this.element.style.opacity = '0';
    setTimeout(() => this.element.remove(), 150);
  }
}


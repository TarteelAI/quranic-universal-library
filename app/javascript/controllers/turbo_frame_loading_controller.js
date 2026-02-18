import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const frame = this.element.querySelector('turbo-frame')
    this.frameId = frame ? frame.id : null
    this.loadingIndicator = this.element.querySelector('#turbo-loading-indicator');
    
    this.boundShowLoading = this.showLoading.bind(this);
    this.boundHideLoading = this.hideLoading.bind(this);
    
    document.addEventListener('turbo:before-fetch-request', this.boundShowLoading);
    document.addEventListener('turbo:frame-render', this.boundHideLoading);
    document.addEventListener('turbo:frame-load', this.boundHideLoading);
    document.addEventListener('turbo:fetch-request-error', this.boundHideLoading);
  }

  showLoading(event) {
    if (!this.frameId) return
    const headers = event?.detail?.fetchOptions?.headers || {}
    const target = headers['Turbo-Frame']
    if (target !== this.frameId) return
    const indicator = this.element.querySelector('#turbo-loading-indicator');
    if (indicator) {
      indicator.classList.remove('tw-hidden');
    }
  }

  hideLoading(event) {
    if (this.frameId) {
      const targetId = event?.target?.id
      if (targetId && targetId !== this.frameId) return
    }
    const indicator = this.element.querySelector('#turbo-loading-indicator');
    if (indicator) {
      indicator.classList.add('tw-hidden');
    }
  }

  disconnect() {
    document.removeEventListener('turbo:before-fetch-request', this.boundShowLoading);
    document.removeEventListener('turbo:frame-render', this.boundHideLoading);
    document.removeEventListener('turbo:frame-load', this.boundHideLoading);
    document.removeEventListener('turbo:fetch-request-error', this.boundHideLoading);
  }
}


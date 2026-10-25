import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['count', 'empty'];

  static values = {
    mode: { type: String, default: 'filter' },
    scope: { type: String, default: '' }
  };

  connect() {
    this.input = this.element.querySelector('#search-input');
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    this.boundHandleInput = this.handleInput.bind(this);

    document.addEventListener('keydown', this.boundHandleKeydown);

    if (this.input && this.modeValue !== 'submit') {
      this.input.addEventListener('input', this.boundHandleInput);
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown);

    if (this.input) {
      this.input.removeEventListener('input', this.boundHandleInput);
    }
  }

  handleInput(event) {
    this.filterResults(event.target.value);
  }

  filterResults(rawQuery) {
    const query = (rawQuery || '').trim().toLowerCase();

    if (!query) {
      this.resetSearch();
      return;
    }

    let visible = 0;

    this.searchItems().forEach((element) => {
      const matches = (element.dataset.search || '').toLowerCase().includes(query);

      element.classList.toggle('!hidden', !matches);
      if (matches) visible += 1;
    });

    this.updateCount(visible);

    if (visible > 0) {
      this.hideEmptyResultsMessage();
    } else {
      this.showEmptyResultsMessage(query);
    }
  }

  resetSearch() {
    const items = this.searchItems();
    items.forEach((element) => element.classList.remove('!hidden'));
    this.updateCount(items.length);
    this.hideEmptyResultsMessage();
  }

  // The results live outside the toolbar, so walk up to the page's results
  // wrapper rather than searching only inside this controller's element.
  resultsRoot() {
    if (this.scopeValue) return document.querySelector(this.scopeValue) || this.element;

    return this.element.closest('#resources') ||
           this.element.closest('.resources-lists') ||
           this.element;
  }

  searchItems() {
    return Array.from(this.resultsRoot().querySelectorAll('[data-search]'));
  }

  updateCount(visible) {
    if (!this.hasCountTarget) return;

    if (this.totalCount === undefined) this.totalCount = this.countTarget.textContent.trim();
    this.countTarget.textContent = visible === this.searchItems().length ? this.totalCount : visible;
  }

  showEmptyResultsMessage(query) {
    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.remove('hidden');
      const term = this.emptyTarget.querySelector('[data-search-term]');
      if (term) term.textContent = query;
    }
    this.element.querySelector('#empty-results-message')?.classList.remove('hidden');
  }

  hideEmptyResultsMessage() {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add('hidden');
    this.element.querySelector('#empty-results-message')?.classList.add('hidden');
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.input?.focus();
    }
  }
}

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { mode: { type: String, default: 'filter' } };

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

    if (query.length <= 1) {
      this.resetSearch();
      return;
    }

    let hasResults = false;

    this.searchItems().forEach((element) => {
      const searchValue = (element.dataset.search || '').toLowerCase();

      if (searchValue.includes(query)) {
        element.classList.remove('!tw-hidden');
        hasResults = true;
      } else {
        element.classList.add('!tw-hidden');
      }
    });

    if (hasResults) {
      this.hideEmptyResultsMessage();
    } else {
      this.showEmptyResultsMessage();
    }
  }

  resetSearch() {
    this.searchItems().forEach((element) => element.classList.remove('!tw-hidden'));
    this.hideEmptyResultsMessage();
  }

  searchItems() {
    return Array.from(this.element.querySelectorAll('[data-search]'));
  }

  showEmptyResultsMessage() {
    this.element.querySelector('#empty-results-message')?.classList.remove('tw-hidden');
  }

  hideEmptyResultsMessage() {
    this.element.querySelector('#empty-results-message')?.classList.add('tw-hidden');
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.input?.focus();
    }
  }
}

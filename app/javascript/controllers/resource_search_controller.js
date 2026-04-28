import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.input = this.el.find('#search-input');
    document.addEventListener('keydown', this.handleKeydown.bind(this));

    this.input.on(
      'DOMAttrModified input change keypress paste blur',
      this.search.bind(this)
    );
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this));
  }

  showEmptyResultsMessage() {
    this.el.find('#empty-results-message').removeClass('hidden');
  }

  hideEmptyResultsMessage() {
    this.el.find('#empty-results-message').addClass('hidden');
  }

  resetSearch() {
    this.searchItems().removeClass('!hidden');
    this.hideEmptyResultsMessage();
  }

  search(event) {
    const query = (event.target.value || '').trim().toLowerCase();
    if (query.length <= 1) {
      this.resetSearch();
      return;
    }

    let hasResults = false;

    this.searchItems().each((_, el) => {
      const resource = $(el);
      const name = resource.data('search').toLowerCase();

      if (name.includes(query)) {
        resource.removeClass('!hidden');
        hasResults = true;
      } else {
        resource.addClass('!hidden');
      }
    });

    if (!hasResults) {
      this.showEmptyResultsMessage();
    } else {
      this.hideEmptyResultsMessage();
    }
  }

  searchItems (){
    return this.el.find('[data-search]')
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault();
      this.input.focus();
    }
  }
}

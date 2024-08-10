import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.input = this.el.find('#search-input');
    document.addEventListener('keydown', this.handleKeydown.bind(this));
    this.input.on('DOMAttrModified input change keypress paste blur', this.search.bind(this));
  }

  search(event) {
    const query = (event.target.value || '').toLowerCase();
    const searchResults = this.el.find('[data-search]');

    if (query.length <= 1) {
      searchResults.removeClass('d-none');
      return;
    }

    let hasResults = false;

    searchResults.each((index, el) => {
      const resource = $(el);
      const name = resource.data('search').toLowerCase();

      if (name.includes(query)) {
        resource.removeClass('d-none');
        hasResults = true;
      } else {
        resource.addClass('d-none');
      }
    });

    if (!hasResults) {
      // Display empty search results message
      this.el.find('#empty-results-message').removeClass('d-none');
    } else {
      // Hide empty search results message
      this.el.find('#empty-results-message').addClass('d-none');
    }
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault();
      this.input.focus();
    }
  }
}

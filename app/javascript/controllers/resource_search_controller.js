import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.input = this.el.find('#search-input');
    document.addEventListener('keydown', this.handleKeydown.bind(this));
    this.input.on('DOMAttrModified input change keypress paste blur', this.search.bind(this));
  }

  search(event) {
    const query = (event.target.value || '').toLowerCase();

    if (query.length <= 1) {
      this.el.find('[data-search]').removeClass('d-none');
      return;
    }

    this.el.find("[data-search]").each((index, el) => {
      const resource = $(el);
      const name = resource.data('search').toLowerCase();

      if (name.includes(query)) {
        resource.removeClass('d-none');
      } else {
        resource.addClass('d-none');
      }
    });
  }

  handleKeydown(event){
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault();
      this.input.focus();
    }
  }
}
import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const currentPage = Number(this.element.dataset.page);

    document.querySelectorAll('a[data-turbo-frame]').forEach(link => {
      const url = new URL(link.href);
      const linkText = link.textContent.trim().toLowerCase();
      let targetPage = currentPage;

      if (linkText === 'previous page') {
        targetPage = Math.max(1, currentPage - 1);
      } else if (linkText === 'next page') {
        targetPage = currentPage + 1;
      }

      url.searchParams.set('page_number', targetPage);
      link.href = url.toString();
    });
  }
}
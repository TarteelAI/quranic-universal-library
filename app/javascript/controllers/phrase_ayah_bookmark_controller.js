// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import AjaxModalController from "./ajax_modal_controller"
import LocalStore from "../utils/LocalStore";

export default class extends AjaxModalController {
  connect() {
    this.store = new LocalStore();
    $(this.element).on("click", e => {
      this.loadModal(e);
    });
  }

  loadModal(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    this.createModal();
    this.show();
    this.renderBookmarks();
  }

  renderBookmarks() {
    const bookmarks = this.store.get('bookmarks') || [];
    let html = '';

    if (bookmarks.length === 0) {
      html = '<div class="p-4 text-center text-gray-500">No bookmarks found.</div>';
    } else {
      html = '<div class="divide-y divide-gray-100">';
      bookmarks.forEach(bookmark => {
        html += `
          <div class="p-4 hover:bg-gray-50 transition-colors">
            <a href="${bookmark.url}" class="block">
              <div class="font-medium text-gray-900">${bookmark.key}</div>
              <div class="text-sm text-gray-500 mt-1">${bookmark.text}</div>
            </a>
          </div>
        `;
      });
      html += '</div>';
    }

    this.setContent('Bookmarks', html);
  }
}
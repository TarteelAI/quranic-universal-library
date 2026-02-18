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
      html = '<div class="tw-p-4 tw-text-center tw-text-gray-500">No bookmarks found.</div>';
    } else {
      html = '<div class="tw-divide-y tw-divide-gray-100">';
      bookmarks.forEach(bookmark => {
        html += `
          <div class="tw-p-4 hover:tw-bg-gray-50 tw-transition-colors">
            <a href="${bookmark.url}" class="tw-block">
              <div class="tw-font-medium tw-text-gray-900">${bookmark.key}</div>
              <div class="tw-text-sm tw-text-gray-500 tw-mt-1">${bookmark.text}</div>
            </a>
          </div>
        `;
      });
      html += '</div>';
    }

    this.setContent('Bookmarks', html);
  }
}
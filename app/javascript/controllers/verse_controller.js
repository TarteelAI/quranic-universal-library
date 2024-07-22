import {Controller} from "@hotwired/stimulus";
import {Popover} from "bootstrap";

export default class extends Controller {
  connect() {
    this.element.addEventListener('mouseup', this.addPopoverToSelection);
  }

  addPopoverToSelection() {
    var selectedText = this.getSelectedNode();

    if (selectedText !== '') {
      var popoverContent = "Hello";
      $(s).popover({
        title: 'Selected Text',
        content: popoverContent,
        placement: 'top',
        trigger: 'manual',
      }).popover('show');
    }

    // this.tip = new Popover(this.element, {html: true})
  }

  getSelectedNode() {
    var text = '';
    if (window.getSelection) {
      text = window.getSelection().toString();
    } else if (document.selection && document.selection.type !== 'Control') {
      text = document.selection.createRange().text;
    }
    return text;
  }

  disconnect() {
    this.tip.hide()
    this.tip.dispose()
  }
}

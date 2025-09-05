import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener(
      "mouseup",
      this.addPopoverToSelection.bind(this),
    );
  }

  addPopoverToSelection() {
    var selectedText = this.getSelectedNode();

    if (selectedText !== "") {
      // Custom popover implementation without Bootstrap
      this.showCustomPopover(selectedText);
    }
  }

  showCustomPopover(text) {
    // Remove any existing popovers
    const existingPopover = document.querySelector(".custom-popover");
    if (existingPopover) {
      existingPopover.remove();
    }

    // Create custom popover element
    const popover = document.createElement("div");
    popover.className = "custom-popover";
    popover.style.cssText = `
      position: absolute;
      background: #333;
      color: white;
      padding: 8px 12px;
      border-radius: 4px;
      font-size: 12px;
      z-index: 1000;
      max-width: 200px;
      word-wrap: break-word;
    `;
    popover.textContent = `Selected: ${text}`;

    // Position the popover
    const selection = window.getSelection();
    if (selection.rangeCount > 0) {
      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      popover.style.left = rect.left + window.scrollX + "px";
      popover.style.top = rect.top + window.scrollY - 30 + "px";
    }

    document.body.appendChild(popover);

    // Auto-hide after 3 seconds
    setTimeout(() => {
      if (popover.parentNode) {
        popover.remove();
      }
    }, 3000);
  }

  getSelectedNode() {
    var text = "";
    if (window.getSelection) {
      text = window.getSelection().toString();
    } else if (document.selection && document.selection.type !== "Control") {
      text = document.selection.createRange().text;
    }
    return text;
  }

  disconnect() {
    this.element.removeEventListener(
      "mouseup",
      this.addPopoverToSelection.bind(this),
    );
  }
}

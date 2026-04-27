import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener('mouseup', this.addPopoverToSelection.bind(this));
    this.currentPopover = null;
  }

  addPopoverToSelection() {
    const selectedText = this.getSelectedNode();

    if (selectedText !== '' && !this.currentPopover) {
      const selection = window.getSelection();
      if (selection.rangeCount > 0) {
        const range = selection.getRangeAt(0);
        const rect = range.getBoundingClientRect();
        
        this.createPopover(selectedText, rect);
      }
    }
  }

  getSelectedNode() {
    if (window.getSelection) {
      return window.getSelection().toString();
    } else if (document.selection && document.selection.type !== 'Control') {
      return document.selection.createRange().text;
    }
    return '';
  }

  createPopover(text, rect) {
    if (this.currentPopover) {
      this.removePopover();
    }
    
    const popover = document.createElement('div');
    popover.className = 'absolute z-50 bg-white rounded-lg shadow-xl border border-gray-200 p-3 max-w-xs opacity-0 transition-opacity duration-200';
    popover.style.position = 'fixed';
    popover.style.left = `${rect.left + (rect.width / 2)}px`;
    popover.style.top = `${rect.top - 10}px`;
    popover.style.transform = 'translate(-50%, -100%)';
    
    const content = document.createElement('div');
    content.className = 'text-sm text-gray-700';
    content.textContent = text || 'Hello';
    popover.appendChild(content);
    
    document.body.appendChild(popover);
    this.currentPopover = popover;
    
    requestAnimationFrame(() => {
      popover.classList.remove('opacity-0');
      popover.classList.add('opacity-100');
    });
    
    setTimeout(() => {
      this.removePopover();
    }, 3000);
    
    document.addEventListener('click', this.removePopover.bind(this), { once: true });
    document.addEventListener('selectionchange', this.removePopover.bind(this), { once: true });
  }

  removePopover() {
    if (this.currentPopover && this.currentPopover.parentNode) {
      this.currentPopover.classList.remove('opacity-100');
      this.currentPopover.classList.add('opacity-0');
      setTimeout(() => {
        if (this.currentPopover && this.currentPopover.parentNode) {
          this.currentPopover.parentNode.removeChild(this.currentPopover);
        }
        this.currentPopover = null;
      }, 200);
    }
  }

  disconnect() {
    this.removePopover();
    this.element.removeEventListener('mouseup', this.addPopoverToSelection);
  }
}

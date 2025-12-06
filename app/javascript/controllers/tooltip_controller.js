import { Controller } from "@hotwired/stimulus";
import { Tooltip } from "flowbite";

export default class extends Controller {
  static values = {
    html: { type: Boolean, default: true },
    placement: { type: String, default: 'top' }
  }

  connect() {
    this.title = this.element.getAttribute('title') || '';
    
    if (!this.title) {
      return;
    }
    
    this.element.removeAttribute('title');
    
  
    if (this.element.tagName === 'svg' && !this.element.style.pointerEvents) {
      this.element.style.pointerEvents = 'auto';
    }
    
    
    const tooltipId = `tooltip-${Math.random().toString(36).substr(2, 9)}`;
    const tooltipElement = document.createElement('div');
    tooltipElement.id = tooltipId;
    tooltipElement.setAttribute('role', 'tooltip');
    tooltipElement.className = 'absolute z-10 inline-block tw-px-3 tw-py-2 tw-text-sm tw-font-medium tw-text-white tw-bg-black tw-rounded-lg tw-shadow-sm opacity-0 tooltip tw-max-w-xs tw-break-words';
    
    if (this.htmlValue) {
      tooltipElement.innerHTML = this.title;
    } else {
      tooltipElement.textContent = this.title;
    }
    
    
    document.body.appendChild(tooltipElement);
    this.tooltipElement = tooltipElement;
    
    
    this.tooltipInstance = new Tooltip(
      tooltipElement,
      this.element,
      {
        placement: this.placementValue || 'top',
        triggerType: 'hover'
      }
    );
  }

  disconnect() {
    if (this.tooltipInstance) {
      try {
        this.tooltipInstance.hide();
      } catch (e) {
      }
      this.tooltipInstance = null;
    }
    
    if (this.tooltipElement && this.tooltipElement.parentNode) {
      this.tooltipElement.parentNode.removeChild(this.tooltipElement);
    }
    
    if (this.title) {
      this.element.setAttribute('title', this.title);
    }
  }
}

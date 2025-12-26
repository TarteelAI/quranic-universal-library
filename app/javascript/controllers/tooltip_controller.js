import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    html: { type: Boolean, default: true },
    placement: { type: String, default: 'top' }
  }

  connect() {
    this.title = this.element.getAttribute('title') || '';
    
    this.element.removeAttribute('title');
    
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'tw-absolute tw-z-50 tw-px-2 tw-py-1 tw-text-sm tw-text-white tw-bg-gray-900 tw-rounded tw-shadow-lg tw-pointer-events-none tw-opacity-0 tw-transition-opacity tw-duration-200 tw-max-w-xs';
    this.tooltip.setAttribute('role', 'tooltip');
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.style.overflow = 'visible';
    this.tooltip.style.position = 'fixed';
    this.tooltip.style.display = 'none';
    
    const contentWrapper = document.createElement('div');
    if (this.htmlValue) {
      contentWrapper.innerHTML = this.title;
    } else {
      contentWrapper.textContent = this.title;
    }
    this.tooltip.appendChild(contentWrapper);
    
    this.arrow = document.createElement('div');
    this.arrow.className = 'tw-absolute tw-w-0 tw-h-0';
    this.arrow.style.pointerEvents = 'none';
    this.arrow.style.zIndex = '51';
    this.tooltip.appendChild(this.arrow);
    
    this.updateArrowDirection(this.placementValue);
    
    document.body.appendChild(this.tooltip);
    
    this.showTooltip = this.showTooltip.bind(this);
    this.hideTooltip = this.hideTooltip.bind(this);
    
    this.element.addEventListener('mouseenter', this.showTooltip);
    this.element.addEventListener('mouseleave', this.hideTooltip);
    this.element.addEventListener('focus', this.showTooltip);
    this.element.addEventListener('blur', this.hideTooltip);
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.showTooltip);
    this.element.removeEventListener('mouseleave', this.hideTooltip);
    this.element.removeEventListener('focus', this.showTooltip);
    this.element.removeEventListener('blur', this.hideTooltip);
    
    if (this.tooltip && this.tooltip.parentNode) {
      this.tooltip.parentNode.removeChild(this.tooltip);
    }
    
    if (this.title) {
      this.element.setAttribute('title', this.title);
    }
  }

  showTooltip() {
    if (!this.title) return;
    
    this.tooltip.style.display = 'block';
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.classList.remove('tw-opacity-0');
    this.tooltip.classList.add('tw-opacity-100');
    
    this.updatePosition();
    
    this.tooltip.style.visibility = 'visible';
  }

  hideTooltip() {
    this.tooltip.classList.remove('tw-opacity-100');
    this.tooltip.classList.add('tw-opacity-0');
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.style.display = 'none';
  }

  updatePosition() {
    const elementRect = this.element.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    const offset = 6;
    
    let placement = this.placementValue;
    let x = 0;
    let y = 0;
    
    const spaceTop = elementRect.top;
    const spaceBottom = viewportHeight - elementRect.bottom;
    const spaceLeft = elementRect.left;
    const spaceRight = viewportWidth - elementRect.right;
    
    if (placement === 'top' && spaceTop < tooltipRect.height + offset) {
      placement = spaceBottom > spaceTop ? 'bottom' : 'top';
    } else if (placement === 'bottom' && spaceBottom < tooltipRect.height + offset) {
      placement = spaceTop > spaceBottom ? 'top' : 'bottom';
    }
    
    this.updateArrowDirection(placement);
    
    switch (placement) {
      case 'top':
        x = elementRect.left + (elementRect.width / 2) - (tooltipRect.width / 2);
        y = elementRect.top - tooltipRect.height - offset;
        break;
      case 'bottom':
        x = elementRect.left + (elementRect.width / 2) - (tooltipRect.width / 2);
        y = elementRect.bottom + offset;
        break;
      case 'left':
        x = elementRect.left - tooltipRect.width - offset;
        y = elementRect.top + (elementRect.height / 2) - (tooltipRect.height / 2);
        break;
      case 'right':
        x = elementRect.right + offset;
        y = elementRect.top + (elementRect.height / 2) - (tooltipRect.height / 2);
        break;
    }
    
    const padding = 8;
    x = Math.max(padding, Math.min(x, viewportWidth - tooltipRect.width - padding));
    y = Math.max(padding, Math.min(y, viewportHeight - tooltipRect.height - padding));
    
    this.tooltip.style.left = `${x}px`;
    this.tooltip.style.top = `${y}px`;
  }

  updateArrowDirection(placement) {
    this.arrow.style.borderLeft = '';
    this.arrow.style.borderRight = '';
    this.arrow.style.borderTop = '';
    this.arrow.style.borderBottom = '';
    this.arrow.style.top = '';
    this.arrow.style.bottom = '';
    this.arrow.style.left = '';
    this.arrow.style.right = '';
    this.arrow.style.transform = '';
    this.arrow.style.marginLeft = '';
    this.arrow.style.marginTop = '';
    
    const arrowColor = 'rgb(17, 24, 39)';
    
    switch (placement) {
      case 'top':
        this.arrow.style.borderLeft = '6px solid transparent';
        this.arrow.style.borderRight = '6px solid transparent';
        this.arrow.style.borderTop = `6px solid ${arrowColor}`;
        this.arrow.style.bottom = '-6px';
        this.arrow.style.left = '50%';
        this.arrow.style.marginLeft = '-6px';
        break;
      case 'bottom':
        this.arrow.style.borderLeft = '6px solid transparent';
        this.arrow.style.borderRight = '6px solid transparent';
        this.arrow.style.borderBottom = `6px solid ${arrowColor}`;
        this.arrow.style.top = '-6px';
        this.arrow.style.left = '50%';
        this.arrow.style.marginLeft = '-6px';
        break;
      case 'left':
        this.arrow.style.borderTop = '6px solid transparent';
        this.arrow.style.borderBottom = '6px solid transparent';
        this.arrow.style.borderRight = `6px solid ${arrowColor}`;
        this.arrow.style.right = '-6px';
        this.arrow.style.top = '50%';
        this.arrow.style.marginTop = '-6px';
        break;
      case 'right':
        this.arrow.style.borderTop = '6px solid transparent';
        this.arrow.style.borderBottom = '6px solid transparent';
        this.arrow.style.borderLeft = `6px solid ${arrowColor}`;
        this.arrow.style.left = '-6px';
        this.arrow.style.top = '50%';
        this.arrow.style.marginTop = '-6px';
        break;
    }
  }
}

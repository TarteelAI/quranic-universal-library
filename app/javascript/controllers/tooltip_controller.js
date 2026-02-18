import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    html: { type: Boolean, default: true },
    placement: { type: String, default: 'top' },
    text: { type: String, default: '' }
  }

  connect() {
    this.title = this.textValue || this.element.getAttribute('title') || this.element.getAttribute('data-tooltip') || '';
    
    if (!this.title || !this.title.trim()) {
      return;
    }
    
    this.element.removeAttribute('title');
    
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'tw-absolute tw-z-[10000] tw-px-3 tw-py-2 tw-text-sm tw-text-white tw-bg-gray-900 tw-rounded-md tw-shadow-xl tw-pointer-events-none tw-opacity-0 tw-transition-opacity tw-duration-200 tw-max-w-xs tw-whitespace-normal';
    this.tooltip.setAttribute('role', 'tooltip');
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.style.overflow = 'visible';
    this.tooltip.style.display = 'none';
    this.tooltip.style.wordWrap = 'break-word';
    
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
    this.element.addEventListener('mouseover', this.showTooltip);
    this.element.addEventListener('mouseout', this.hideTooltip);
    this.element.addEventListener('focus', this.showTooltip);
    this.element.addEventListener('blur', this.hideTooltip);
    
    const svg = this.element.querySelector('svg');
    if (svg) {
      svg.addEventListener('mouseenter', this.showTooltip);
      svg.addEventListener('mouseleave', this.hideTooltip);
    }
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.showTooltip);
    this.element.removeEventListener('mouseleave', this.hideTooltip);
    this.element.removeEventListener('mouseover', this.showTooltip);
    this.element.removeEventListener('mouseout', this.hideTooltip);
    this.element.removeEventListener('focus', this.showTooltip);
    this.element.removeEventListener('blur', this.hideTooltip);
    
    const svg = this.element.querySelector('svg');
    if (svg) {
      svg.removeEventListener('mouseenter', this.showTooltip);
      svg.removeEventListener('mouseleave', this.hideTooltip);
    }
    
    if (this.tooltip && this.tooltip.parentNode) {
      this.tooltip.parentNode.removeChild(this.tooltip);
    }
    
    if (this.title) {
      this.element.setAttribute('title', this.title);
    }
  }

  showTooltip(event) {
    if (!this.title || !this.title.trim()) {
      return;
    }
    
    if (!this.tooltip) {
      return;
    }
    
    this.tooltip.style.display = 'block';
    this.tooltip.style.position = 'fixed';
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.style.left = '-9999px';
    this.tooltip.style.top = '0px';
    this.tooltip.style.opacity = '0';
    
    void this.tooltip.offsetWidth;
    
    this.updatePosition();
    
    this.tooltip.style.visibility = 'visible';
    this.tooltip.style.opacity = '1';
    this.tooltip.style.display = 'block';
    this.tooltip.classList.remove('tw-opacity-0');
    this.tooltip.classList.add('tw-opacity-100');
  }

  hideTooltip() {
    this.tooltip.classList.remove('tw-opacity-100');
    this.tooltip.classList.add('tw-opacity-0');
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.style.display = 'none';
  }

  updatePosition() {
    const elementRect = this.element.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const scrollX = window.scrollX || window.pageXOffset;
    const scrollY = window.scrollY || window.pageYOffset;
    
    const offset = 8;
    
    let placement = this.placementValue;
    let x = 0;
    let y = 0;
    
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const tooltipWidth = tooltipRect.width > 0 ? tooltipRect.width : (this.tooltip.offsetWidth || 200);
    const tooltipHeight = tooltipRect.height > 0 ? tooltipRect.height : (this.tooltip.offsetHeight || 50);
    
    const spaceTop = elementRect.top;
    const spaceBottom = viewportHeight - elementRect.bottom;
    const spaceLeft = elementRect.left;
    const spaceRight = viewportWidth - elementRect.right;
    
    if (placement === 'top' && spaceTop < tooltipHeight + offset) {
      placement = spaceBottom > spaceTop ? 'bottom' : 'top';
    } else if (placement === 'bottom' && spaceBottom < tooltipHeight + offset) {
      placement = spaceTop > spaceBottom ? 'top' : 'bottom';
    }
    
    this.updateArrowDirection(placement);
    
    switch (placement) {
      case 'top':
        x = elementRect.left + (elementRect.width / 2) - (tooltipWidth / 2);
        y = elementRect.top - tooltipHeight - offset;
        break;
      case 'bottom':
        x = elementRect.left + (elementRect.width / 2) - (tooltipWidth / 2);
        y = elementRect.bottom + offset;
        break;
      case 'left':
        x = elementRect.left - tooltipWidth - offset;
        y = elementRect.top + (elementRect.height / 2) - (tooltipHeight / 2);
        break;
      case 'right':
        x = elementRect.right + offset;
        y = elementRect.top + (elementRect.height / 2) - (tooltipHeight / 2);
        break;
    }
    
    const padding = 8;
    x = Math.max(padding, Math.min(x, viewportWidth - tooltipWidth - padding));
    y = Math.max(padding, Math.min(y, viewportHeight - tooltipHeight - padding));
    
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

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    placement: { type: String, default: 'right' },
    trigger: { type: String, default: 'focus' }
  }

  connect() {
    this.title = this.element.getAttribute('data-bs-title') || this.element.getAttribute('title') || '';
    this.content = this.element.getAttribute('data-bs-content') || '';
    
    if (this.title) {
      this.element.removeAttribute('title');
    }
    
    this.createPopover();
    
    if (this.triggerValue === 'focus') {
      this.element.addEventListener('focus', this.show);
      this.element.addEventListener('blur', this.hide);
    } else if (this.triggerValue === 'click') {
      this.element.addEventListener('click', this.toggle);
    } else {
      this.element.addEventListener('mouseenter', this.show);
      this.element.addEventListener('mouseleave', this.hide);
    }
  }

  disconnect() {
    this.element.removeEventListener('focus', this.show);
    this.element.removeEventListener('blur', this.hide);
    this.element.removeEventListener('click', this.toggle);
    this.element.removeEventListener('mouseenter', this.show);
    this.element.removeEventListener('mouseleave', this.hide);
    
    if (this.popoverElement && this.popoverElement.parentNode) {
      this.popoverElement.parentNode.removeChild(this.popoverElement);
    }
    
    if (this.title) {
      this.element.setAttribute('title', this.title);
    }
  }

  createPopover() {
    this.popoverElement = document.createElement('div');
    this.popoverElement.className = 'absolute z-50 bg-white rounded-lg shadow-xl border border-gray-200 p-4 max-w-sm opacity-0 transition-opacity duration-200 pointer-events-none';
    this.popoverElement.setAttribute('role', 'tooltip');
    this.popoverElement.style.visibility = 'hidden';
    this.popoverElement.style.position = 'fixed';
    this.popoverElement.style.display = 'none';
    
    if (this.title) {
      const titleEl = document.createElement('div');
      titleEl.className = 'font-semibold text-gray-900 mb-2';
      titleEl.innerHTML = this.title;
      this.popoverElement.appendChild(titleEl);
    }
    
    if (this.content) {
      const contentEl = document.createElement('div');
      contentEl.className = 'text-sm text-gray-700';
      contentEl.innerHTML = this.content;
      this.popoverElement.appendChild(contentEl);
    }
    
    this.arrow = document.createElement('div');
    this.arrow.className = 'absolute w-0 h-0';
    this.arrow.style.pointerEvents = 'none';
    this.arrow.style.zIndex = '51';
    this.popoverElement.appendChild(this.arrow);
    
    document.body.appendChild(this.popoverElement);
    
    this.show = this.show.bind(this);
    this.hide = this.hide.bind(this);
    this.toggle = this.toggle.bind(this);
  }

  show = () => {
    if (!this.title && !this.content) return;
    
    this.popoverElement.style.display = 'block';
    this.popoverElement.style.visibility = 'hidden';
    this.popoverElement.classList.remove('opacity-0');
    this.popoverElement.classList.add('opacity-100');
    this.popoverElement.classList.remove('pointer-events-none');
    
    this.updatePosition();
    
    this.popoverElement.style.visibility = 'visible';
  }

  hide = () => {
    this.popoverElement.classList.remove('opacity-100');
    this.popoverElement.classList.add('opacity-0');
    this.popoverElement.classList.add('pointer-events-none');
    this.popoverElement.style.visibility = 'hidden';
    this.popoverElement.style.display = 'none';
  }

  toggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (this.popoverElement.classList.contains('opacity-0')) {
      this.show();
    } else {
      this.hide();
    }
  }

  updatePosition() {
    const elementRect = this.element.getBoundingClientRect();
    const popoverRect = this.popoverElement.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const scrollX = window.scrollX || window.pageXOffset;
    const scrollY = window.scrollY || window.pageYOffset;
    
    const offset = 8;
    let placement = this.element.getAttribute('data-bs-placement') || this.placementValue;
    
    let x = 0;
    let y = 0;
    
    const spaceTop = elementRect.top;
    const spaceBottom = viewportHeight - elementRect.bottom;
    const spaceLeft = elementRect.left;
    const spaceRight = viewportWidth - elementRect.right;
    
    if (placement === 'top' && spaceTop < popoverRect.height + offset) {
      placement = spaceBottom > spaceTop ? 'bottom' : 'top';
    } else if (placement === 'bottom' && spaceBottom < popoverRect.height + offset) {
      placement = spaceTop > spaceBottom ? 'top' : 'bottom';
    } else if (placement === 'left' && spaceLeft < popoverRect.width + offset) {
      placement = spaceRight > spaceLeft ? 'right' : 'left';
    } else if (placement === 'right' && spaceRight < popoverRect.width + offset) {
      placement = spaceLeft > spaceRight ? 'left' : 'right';
    }
    
    this.updateArrowDirection(placement);
    
    switch (placement) {
      case 'top':
        x = elementRect.left + (elementRect.width / 2) - (popoverRect.width / 2);
        y = elementRect.top - popoverRect.height - offset;
        break;
      case 'bottom':
        x = elementRect.left + (elementRect.width / 2) - (popoverRect.width / 2);
        y = elementRect.bottom + offset;
        break;
      case 'left':
        x = elementRect.left - popoverRect.width - offset;
        y = elementRect.top + (elementRect.height / 2) - (popoverRect.height / 2);
        break;
      case 'right':
        x = elementRect.right + offset;
        y = elementRect.top + (elementRect.height / 2) - (popoverRect.height / 2);
        break;
    }
    
    const padding = 8;
    x = Math.max(padding, Math.min(x, viewportWidth - popoverRect.width - padding));
    y = Math.max(padding, Math.min(y, viewportHeight - popoverRect.height - padding));
    
    this.popoverElement.style.left = `${x + scrollX}px`;
    this.popoverElement.style.top = `${y + scrollY}px`;
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
    this.arrow.style.marginLeft = '';
    this.arrow.style.marginTop = '';
    
    const arrowColor = 'rgb(229, 231, 235)';
    const arrowBorderColor = 'rgb(209, 213, 219)';
    
    switch (placement) {
      case 'top':
        this.arrow.style.borderLeft = '8px solid transparent';
        this.arrow.style.borderRight = '8px solid transparent';
        this.arrow.style.borderTop = `8px solid ${arrowBorderColor}`;
        this.arrow.style.bottom = '-8px';
        this.arrow.style.left = '50%';
        this.arrow.style.marginLeft = '-8px';
        break;
      case 'bottom':
        this.arrow.style.borderLeft = '8px solid transparent';
        this.arrow.style.borderRight = '8px solid transparent';
        this.arrow.style.borderBottom = `8px solid ${arrowBorderColor}`;
        this.arrow.style.top = '-8px';
        this.arrow.style.left = '50%';
        this.arrow.style.marginLeft = '-8px';
        break;
      case 'left':
        this.arrow.style.borderTop = '8px solid transparent';
        this.arrow.style.borderBottom = '8px solid transparent';
        this.arrow.style.borderLeft = `8px solid ${arrowBorderColor}`;
        this.arrow.style.right = '-8px';
        this.arrow.style.top = '50%';
        this.arrow.style.marginTop = '-8px';
        break;
      case 'right':
        this.arrow.style.borderTop = '8px solid transparent';
        this.arrow.style.borderBottom = '8px solid transparent';
        this.arrow.style.borderRight = `8px solid ${arrowBorderColor}`;
        this.arrow.style.left = '-8px';
        this.arrow.style.top = '50%';
        this.arrow.style.marginTop = '-8px';
        break;
    }
  }
}

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    this.pos = { left: 0, top: 0, x: 0, y: 0 };
    this.element.style.cursor = 'grab';
    this.isDragging = false;

    this.mouseMoveHandler = this.mouseMoveHandler.bind(this);
    this.mouseUpHandler = this.mouseUpHandler.bind(this);
    this.handleClick = this.handleClick.bind(this);
  }

  mouseDownHandler(event) {
    if (event.button !== 0) return;

    this.isDragging = false;
    this.element.style.cursor = 'grabbing';
    this.element.style.userSelect = 'none';

    this.pos = {
      left: this.element.scrollLeft,
      top: this.element.scrollTop,
      x: event.clientX,
      y: event.clientY,
    };
    this.startX = event.clientX;
    this.startY = event.clientY;

    document.addEventListener('mousemove', this.mouseMoveHandler);
    document.addEventListener('mouseup', this.mouseUpHandler);
    document.addEventListener('click', this.handleClick, true);

    event.preventDefault();
  }

  mouseMoveHandler(event) {
    const dx = event.clientX - this.pos.x;
    const dy = event.clientY - this.pos.y;

    this.element.scrollLeft = this.pos.left - dx;
    // Pan vertically too when the element actually scrolls that way; for a
    // purely side-scrolling container this assignment is a no-op.
    this.element.scrollTop = this.pos.top - dy;

    if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
      this.isDragging = true;
    }
  }

  handleClick(event) {
    if (this.isDragging) {
      event.preventDefault();
      event.stopPropagation();
    }
    document.removeEventListener('click', this.handleClick, true);
  }

  mouseUpHandler() {
    this.element.style.cursor = 'grab';
    this.element.style.removeProperty('user-select');

    document.removeEventListener('mousemove', this.mouseMoveHandler);
    document.removeEventListener('mouseup', this.mouseUpHandler);
  }

  disconnect() {
    document.removeEventListener('mousemove', this.mouseMoveHandler);
    document.removeEventListener('mouseup', this.mouseUpHandler);
    document.removeEventListener('click', this.handleClick, true);
  }
}

import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    this.pos = { left: 0, x: 0 };
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
      x: event.clientX,
    };
    this.startX = event.clientX;

    document.addEventListener('mousemove', this.mouseMoveHandler);
    document.addEventListener('mouseup', this.mouseUpHandler);
    document.addEventListener('click', this.handleClick, true);

    event.preventDefault();
  }

  mouseMoveHandler(event) {
    const dx = event.clientX - this.pos.x;
    this.element.scrollLeft = this.pos.left - dx;

    if (Math.abs(event.clientX - this.startX) > 5) {
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

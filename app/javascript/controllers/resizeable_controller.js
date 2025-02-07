import {Controller} from "@hotwired/stimulus";
import LocalStore from "../utils/LocalStore";

const localStore = new LocalStore();

export default class extends Controller {
  connect() {
    this.leftSide = this.element.querySelector('#left-side');
    this.rightSide = this.element.querySelector('#right-side');
    this.resizeHandler = this.element.querySelector('#resize-handler')
    this.isResizing = false;
    this.id = this.element.id || location.pathname.replaceAll("/", "-");

    this.resizeHandler.addEventListener('mousedown', (e) => {
      e.preventDefault();
      this.isResizing = true;
      this.onResize = document.addEventListener('mousemove', this.resize.bind(this));
      this.onStopResize = document.addEventListener('mouseup', this.stopResize.bind(this));
    });

    const lw = localStore.get(`${this.id}-lw`);
    const rw = localStore.get(`${this.id}-rw`);

    if (lw) {
      this.leftSide.style.width = `${lw}px`;
    }

    if (rw) {
      this.rightSide.style.width = `${rw}px`;
    }
  }

  resize(e) {
    if (!this.isResizing) return;

    const containerWidth = this.leftSide.parentElement.offsetWidth;
    const leftWidth = e.clientX - this.leftSide.getBoundingClientRect().left;
    const rightWidth = containerWidth - leftWidth - this.resizeHandler.offsetWidth;

    if (leftWidth >= 100 && rightWidth >= 100) {
      this.leftSide.style.width = `${leftWidth}px`;
      this.rightSide.style.width = `${rightWidth}px`;
      localStore.set(`${this.id}-lw`, leftWidth);
      localStore.set(`${this.id}-rw`, rightWidth);
    }
  };

  stopResize() {
    this.isResizing = false;
    document.removeEventListener('mousemove', this.onResize);
    document.removeEventListener('mouseup', this.onStopResize);
  };

  disconnect() {
    this.stopResize();
  }
}
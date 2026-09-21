import {Controller} from "@hotwired/stimulus";
import LocalStore from "../utils/LocalStore";

const localStore = new LocalStore();
const MIN_RATIO = 0.15;
const MAX_RATIO = 0.85;

export default class extends Controller {
  connect() {
    this.leftSide = this.element.querySelector('#left-side');
    this.rightSide = this.element.querySelector('#right-side');
    this.resizeHandler = this.element.querySelector('#resize-handler')
    this.isResizing = false;
    this.id = this.element.id || location.pathname.replaceAll("/", "-");

    if (!this.leftSide || !this.rightSide || !this.resizeHandler) return;

    this.onMouseDown = this.startResize.bind(this);
    this.onMouseMove = this.resize.bind(this);
    this.onMouseUp = this.stopResize.bind(this);

    this.resizeHandler.addEventListener('mousedown', this.onMouseDown);

    // Panes are sized with flex-grow ratios instead of pixel widths. Pixel widths
    // force the surrounding table cell to grow and push the page out of the viewport.
    const ratio = parseFloat(localStore.get(`${this.id}-ratio`));
    this.applyRatio(isNaN(ratio) ? 0.5 : ratio);

    // Drop the legacy pixel widths, they break the layout on smaller screens.
    localStore.remove(`${this.id}-lw`);
    localStore.remove(`${this.id}-rw`);
  }

  startResize(e) {
    e.preventDefault();
    this.isResizing = true;
    document.addEventListener('mousemove', this.onMouseMove);
    document.addEventListener('mouseup', this.onMouseUp);
  }

  applyRatio(ratio) {
    const value = Math.min(Math.max(ratio, MIN_RATIO), MAX_RATIO);

    this.leftSide.style.flexGrow = value;
    this.rightSide.style.flexGrow = 1 - value;

    return value;
  }

  resize(e) {
    if (!this.isResizing) return;

    const container = this.leftSide.parentElement;
    const style = window.getComputedStyle(container);

    // clientWidth already excludes the border, padding still needs to go
    const available = container.clientWidth
      - parseFloat(style.paddingLeft)
      - parseFloat(style.paddingRight)
      - this.resizeHandler.offsetWidth;

    if (available <= 0) return;

    const leftWidth = e.clientX - this.leftSide.getBoundingClientRect().left;
    const ratio = this.applyRatio(leftWidth / available);

    localStore.set(`${this.id}-ratio`, ratio);
  };

  stopResize() {
    this.isResizing = false;
    document.removeEventListener('mousemove', this.onMouseMove);
    document.removeEventListener('mouseup', this.onMouseUp);
  };

  disconnect() {
    this.stopResize();

    if (this.resizeHandler) {
      this.resizeHandler.removeEventListener('mousedown', this.onMouseDown);
    }
  }
}

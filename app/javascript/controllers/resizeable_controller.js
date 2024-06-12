import {Controller} from "@hotwired/stimulus"
import LocalStore from "../utils/LocalStore";

const localStore = new LocalStore();

export default class extends Controller {
  connect() {
    const el = this.element;
    this.leftSide = el.querySelector('#left-side');
    this.rightSide = el.querySelector('#right-side');
    this.handler = el.querySelector('.handler');
    this.isResizing = false;
    this.lastX = 0;

    let lw= localStore.get('resize-left-width');
    let rw= localStore.get('resize-right-width');

    if (lw) {
      this.leftSide.style.width = lw;
    }

    if (rw) {
      this.rightSide.style.width = rw;
    }

    this.bindEvents()
  }

  bindEvents() {
    this.handler.addEventListener('mousedown', (e) => {
      e.preventDefault();
      this.isResizing = true;
      this.lastX = e.clientX;
    });

    document.addEventListener('mousemove', (e) => {
      if (!this.isResizing) return;

      const deltaX = e.clientX - this.lastX;
      const newDiv1Width = this.leftSide.offsetWidth + deltaX;
      const newDiv2Width = this.rightSide.offsetWidth - deltaX;

      // Restrict minimum width for div1 and div2
      if (newDiv1Width >= 100 && newDiv2Width >= 100) {
       localStore.set('resize-left-width', `${newDiv1Width}px`);
       localStore.set('resize-right-width', `${newDiv2Width}px`);

        this.leftSide.style.width = `${newDiv1Width}px`;
        this.rightSide.style.width = `${newDiv2Width}px`;
      }

      this.lastX = e.clientX;
    });

    document.addEventListener('mouseup', () => {
      this.isResizing = false;
    });
  }

  disconnect() {
  }
}

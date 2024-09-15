import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const zoomslider = this.element.querySelector('#zoom-slider');
    const zoomableImage = this.element.querySelector('#zoom-image');

    zoomslider.addEventListener('input', function () {
      const scale = zoomslider.value;
      zoomableImage.style.transform = `scale(${scale})`;
    });
  }

  disconnect() {
  }
}

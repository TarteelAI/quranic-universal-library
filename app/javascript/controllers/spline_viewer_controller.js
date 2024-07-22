import {Controller} from "@hotwired/stimulus";
import ScreenSize from "../utils/screen-size";

export default class extends Controller {
  connect() {
    this.device = new ScreenSize();
    this.updateViewer();

    window.addEventListener('resize', () => {
      setTimeout(() => this.updateViewer(), 100);
    });
  }

  updateViewer() {
    this.element.querySelectorAll("spline-viewer").forEach((oldViewer) => {
      const newViewer = document.createElement("spline-viewer");
      newViewer.setAttribute("background", "transparent");
      newViewer.setAttribute("loading-anim-type", "spinner-small-light");
      newViewer.setAttribute("url", "https://prod.spline.design/hSyPwhy9Au9D17VK/scene.splinecode");

      oldViewer.replaceWith(newViewer);
    });

    setTimeout(()=>{this.adjustCanvasSize()}, 100);
  }

  adjustCanvasSize() {
    const {scale, scaleDesktop, scaleLargeDesktop, marginLeft} = this.element.dataset;
    if(scale && scale == '1') {
      return
    }
    const canvas = document.querySelector("spline-viewer").shadowRoot.querySelector("canvas");
    const d = this.device;

    if (d.isDesktop()) {
      // Desktop
      canvas.style.transform = `scale(${scale||scaleDesktop||2.5})`;
      canvas.style.marginLeft = `${marginLeft||'-40px'}`;
    } else if (d.isLargeDesktop()) {
      // Large Desktop
      canvas.style.transform = `scale(${scale||scaleLargeDesktop||3})`;
      canvas.style.marginLeft = `-60px`;
    }
  }
}
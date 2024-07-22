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
    const canvas = document.querySelector("spline-viewer").shadowRoot.querySelector("canvas");

    const {scale, scaleDesktop, scaleLargeDesktop, marginLeft} = this.element.dataset;
    if(scale && scale == '1' || !canvas) {
      return
    }
    const d = this.device;
    let scaleMobile = 1.5;

    if (d.isDesktop()) {
      // Desktop
      let desktopScale = parseFloat(scaleDesktop || scale || 2.5);
      canvas.style.transform = `scale(${desktopScale})`;
      canvas.style.marginLeft = `${marginLeft||'-40px'}`;
    } else if (d.isLargeDesktop()) {
      // Large Desktop
      let largeScreeenScale = parseFloat(scaleLargeDesktop || scale || 2.5);

      canvas.style.transform = `scale(${largeScreeenScale})`;
      canvas.style.marginLeft = `-60px`;
    }
  }
}
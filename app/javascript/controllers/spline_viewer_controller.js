import {Controller} from "@hotwired/stimulus";
import ScreenSize from "../utils/screen-size";

export default class extends Controller {
  connect() {
    this.device = new ScreenSize();
   // this.adjustCanvasSize();

    window.addEventListener('resize', () => {
     // setTimeout(() => this.adjustCanvasSize(), 100);
    });
  }

  adjustCanvasSize() {
    const canvas = this.element.querySelector("canvas");

    const {scale, desktopScale, scaleLargeDesktop, mobileScale, marginLeft} = this.element.dataset;
    if(scale && scale === '1' || !canvas) {
      return
    }
    const d = this.device;

    if(d.isMobile() && mobileScale){
      canvas.style.transform = `scale(${parseFloat(mobileScale)})`;
      console.log("========= mobile", mobileScale)

    } else if (d.isDesktop()) {
      // Desktop
      let s = parseFloat(desktopScale || scale || 1.5);
      canvas.style.transform = `scale(${s})`;
      //canvas.style.marginLeft = `${marginLeft||'-40px'}`;
      console.log("========= desktop", s)
    } else if (d.isLargeDesktop()) {
      // Large Desktop
      let largeScreeenScale = parseFloat(scaleLargeDesktop || scale || 1);
      console.log("========= largeScreeenScale", largeScreeenScale)

      canvas.style.transform = `scale(${largeScreeenScale})`;
     // canvas.style.marginLeft = `-60px`;
    }
  }
}
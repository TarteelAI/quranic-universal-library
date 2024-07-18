import {Controller} from "@hotwired/stimulus";
import ImageZoomer from "../utils/image_zoomer";

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    const {host, page} = this.element.dataset;
    this.imageZommer = new ImageZoomer(this.buildUrl(page))

    this.el.find('#change_page').on('change', this.changePage.bind(this));
  }

  changePage(event) {
    const page = event.target.value;
    this.imageZommer.changeImage(this.buildUrl(page));
  }
  buildUrl(page) {
    page = !!page ? parseInt(page) : 1;
    const {host} = this.element.dataset;

    const imgUrl = `${host}/${page}.jpg`;
    return imgUrl;
  }
}

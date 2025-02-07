import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    const {page} = this.element.dataset;
    this.currentPage = Number(page);

    this.btnJump = this.el.find('#jump-to-page');
    this.btnPrevious = this.el.find('#previous-page');
    this.btnNext = this.el.find('#next-page');

    this.btnJump.on('change', this.jumpToPage.bind(this));
    this.btnPrevious.on('click', this.previousPage.bind(this));
    this.btnNext.on('click', this.nextPage.bind(this));

    const zoomslider = this.element.querySelector('#zoom-slider');

    zoomslider.addEventListener('input', () => {
      const scale = zoomslider.value;
      this.zoom(scale);
    });
  }

  zoom(scale) {
    const zoomableImage = this.element.querySelector('#zoom-image');
    zoomableImage.style.transform = `scale(${scale})`;
  }

  previousPage(event) {
    this.changePage(this.currentPage - 1)
  }
  nextPage(event) {
    this.changePage(this.currentPage + 1)
  }
  jumpToPage(event) {
    const page = event.target.value;
    this.changePage(page)
  }

  changePage(pageNumber) {
    const img = this.element.querySelector('#zoom-image')
    this.currentPage = Number(pageNumber);
    this.el.find("#page").text(pageNumber);

    if(pageNumber <= 1){
      this.btnPrevious.addClass('d-none')
    } else {
      this.btnPrevious.removeClass('d-none')
    }

    img.src = this.buildUrl(pageNumber)
  }

  buildUrl(page) {
    page = !!page ? parseInt(page) : 1;
    const {host, format} = this.element.dataset;

    return `${host}/${page}.${format || 'jpg'}`;
  }
}

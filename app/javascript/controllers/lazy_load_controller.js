import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if ("IntersectionObserver" in window) {
      this.createObserver();
    } else {
      this.loadImage();
    }
  }

  createObserver() {
    const observerOptions = {
      root: null,
      threshold: 0.1,
    };

    const observer = new IntersectionObserver(this.handleIntersect.bind(this), observerOptions);
    observer.observe(this.element);
  }

  handleIntersect(entries, observer) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        this.loadImage();
        observer.unobserve(this.element); // Stop observing once the image is loaded
      }
    });
  }

  loadImage() {
    const img = this.element;
    const dataSrc = img.getAttribute("data-src");
    if (dataSrc) {
      img.src = dataSrc;
    }
  }
}

import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.player = this.element.querySelector('#player');

    const {ayah} = this.element.dataset;
    if (ayah) {
      const ayahToJump = this.element.querySelector(`[data-ayah="${ayah}"]`);
      if (ayahToJump)
        ayahToJump.scrollIntoView({behavior: 'smooth', block: 'center'})
    }

    this.el.find('.play-segment').on('click', this.playSegment.bind(this))
  }

  playSegment(event) {
    const el = event.target;
    const start = parseFloat(el.dataset.start) / 1000;
    const end = parseFloat(el.dataset.end) / 1000;

    this.player.currentTime = start;
    this.player.play();

    const updatePlayerProgress = () => {
      if (this.player.currentTime >= end) {
        this.player.pause();
        this.player.removeEventListener('timeupdate', updatePlayerProgress);
      }
    };

    this.player.addEventListener('timeupdate', updatePlayerProgress);
  }
}


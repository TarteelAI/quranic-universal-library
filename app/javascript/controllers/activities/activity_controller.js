import {Controller} from "@hotwired/stimulus";
import {loadJavascript} from "../../utils/script_loader";

export default class extends Controller {
  connect() {
    loadJavascript('https://cdn.jsdelivr.net/npm/@tsparticles/confetti@3.0.3/tsparticles.confetti.bundle.min.js')
    this.el = $(this.element)
    this.resultBox = $('#quiz-result')
    this.moreActivities = $('.more-activities')
    this.moreActivities.addClass('d-none');
  }

  onSuccess() {
    this.showConfetti();
    this.resultBox.find('#correct-message').removeClass('d-none');
    this.resultBox.find('#incorrect-message').addClass('d-none');
    this.nextAction()
  }

  wrongAnswer() {
    this.resultBox.find('#correct-message').addClass('d-none');
    this.resultBox.find('#incorrect-message').removeClass('d-none').addClass('shake');

    setTimeout(() => {
      this.resultBox.find('#incorrect-message').removeClass('shake');
    }, 500)

    setTimeout(() => {
      this.element.classList.remove('wrong-answer');
    }, 1000)
  }


  nextAction() {
    const ayahKey = this.el.data('ayah');
    const ayah = this.moreActivities.find('.ayah-info');
    ayah.data("url", `/ayah/${ayahKey}`);

    setTimeout(() => {
      this.moreActivities.removeClass('d-none');
      this.moreActivities.addClass('shake');
    }, 4500)
  }


  showConfetti() {
    const count = 200,
      defaults = {
        origin: {y: 0.7},
      };

    const fire = (particleRatio, opts) => {
      confetti(
        Object.assign({}, defaults, opts, {
          particleCount: Math.floor(count * particleRatio),
        })
      );
    }

    fire(0.25, {
      spread: 26,
      startVelocity: 55,
    });

    fire(0.2, {
      spread: 60,
    });

    fire(0.35, {
      spread: 100,
      decay: 0.91,
      scalar: 0.8,
    });

    fire(0.1, {
      spread: 120,
      startVelocity: 25,
      decay: 0.92,
      scalar: 1.2,
    });

    fire(0.1, {
      spread: 120,
      startVelocity: 45,
    });

    setTimeout(() => {
      confetti({
        particleCount: 300,
        spread: 80,
        origin: {y: 0.6},
      })
    }, 1000)

    setTimeout(() => {
      confetti({
        particleCount: 1000,
        spread: 80,
        origin: {y: 0.6},
      })
    }, 2000)
  }
}

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.el = $(this.element);

    this.el.on('click', '.question-wrapper', (event) => {
      event.preventDefault();
      const item = $(event.target).closest('.item');
      const isActive = item.hasClass('active');

      item.toggleClass('active');
      item.find('.answer-wrapper').slideToggle(300);

      if (!isActive) {
        const id = item.attr('id');
        if (id) {
          history.replaceState(null, null, `#${id}`);
        }
      }
    });

    this.focusCurrentQuestion();
  }

  focusCurrentQuestion() {
    const hash = window.location.hash;
    if (hash && hash.startsWith("#faq-")) {
      const targetItem = $(hash);
      if (targetItem.length) {
        const answer = targetItem.find('.answer-wrapper');

        setTimeout(() => {
          targetItem[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
          targetItem.addClass('active');
          answer.slideDown(300);
        }, 100);
      }
    }
  }
}

import ActivityController from "./activity_controller";

export default class extends ActivityController {
  connect() {
    super.connect();

    $(this.element).find('.option').on('click', this.checkAnswer.bind(this))
  }

  checkAnswer(e) {
    e.preventDefault();
    const button = $(e.target);
    
    if (button.attr('disabled')) {
      return;
    }

    const {correct} = e.target.dataset;

    if (correct == 'true') {
      this.handleCorrectAnswer(button);
    } else {
      this.handleWrongAnswer(button);
    }
  }

  handleCorrectAnswer(correctButton) {
    this.el.find(".option").attr('disabled', 'disabled');
    correctButton.addClass('correct-answer');
    this.onSuccess();
  }

  handleWrongAnswer(wrongButton) {
    wrongButton.addClass('wrong-answer shake');
    wrongButton.attr('disabled', 'disabled');
    
    this.wrongAnswer();

    setTimeout(() => {
      wrongButton.removeClass('shake');
      wrongButton.removeClass('wrong-answer');
      wrongButton.removeAttr('disabled');
    }, 1000);
  }
}

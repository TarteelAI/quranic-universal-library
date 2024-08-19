import ActivityController from "./activity_controller";

export default class extends ActivityController {
  connect() {
    super.connect();

    $(this.element).find('.option').on('click', this.checkAnswer.bind(this))
  }

  checkAnswer(e) {
    e.preventDefault();
    const {correct} = e.target.dataset;

    if (correct == 'true') {
      this.onSuccess();
      this.el.find(".option").attr('disabled', 'disabled');
    } else
      this.wrongAnswer();
  }
}

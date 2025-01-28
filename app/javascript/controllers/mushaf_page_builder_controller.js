import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.el.find("#decrement").on("click", this.decrementPage.bind(this));
    this.el.find("#increment").on("click", this.incrementPage.bind(this));

    $(".mushaf-layout-form .remove-ayah").on('click', (event) => {
      event.preventDefault()
      $(event.target).closest(".verse").remove()
    });

    $(".mushaf-layout-form .line-number-input").on('change', (event) => {
      const ayahNumber = Number(event.currentTarget.dataset.verse);
      const positionNumber = Number(event.currentTarget.dataset.wordPosition);
      const lineNumber = Number(event.currentTarget.value);
      const propagate = $("#propagate-changes").is(":checked")

      if (lineNumber == 0 || propagate == false)
        return;

      document.querySelectorAll('.line-number-input').forEach((input) => {
        var line = Number(input.value);
        var ayah = Number(input.dataset.verse)
        const position = Number(input.dataset.wordPosition);

        if (ayah > ayahNumber) {
          input.value = lineNumber;
        } else if(ayah == ayahNumber){
          if(position > positionNumber)
            input.value = lineNumber;
        }
      })
    });
  }

  decrementPage(){
this.changePageNumberForAllWords(-1);
  }
  incrementPage(){
    this.changePageNumberForAllWords(1);
  }

  changePageNumberForAllWords(change){
    document.querySelectorAll('.line-number-input').forEach((input) => {
      var line = Number(input.value);
      if(line != 0)
        input.value = line + change;
    })
  }
}

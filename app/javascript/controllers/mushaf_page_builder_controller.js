import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    /*$(".mushaf-pages").on("ajax:success", (event, response, status) => {
      var form = $(event.target)
      var page = response.page;

      form.find("#submit").val(response.message);
      form.find(`#${page}-from .help-block`).html(response.from)
      form.find(`#${page}-to .help-block`).html(response.to)

      var nextPageFrom = $(`#${page + 1}-from .from`);
      var nextPageTo = $(`#${page + 1}-from .to`);

      if (nextPageFrom.val().length == 0)
        nextPageFrom.val(response.next.from)

      if (!nextPageTo.val())
        nextPageTo.val(response.next.to)
    })*/

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

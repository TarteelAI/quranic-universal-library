import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    var footnote = $('.translation sup')
    if (footnote.length) {
      footnote.click(function (e) {
        e.preventDefault()
        e.stopImmediatePropagation()
        var footnoteId = $(this).attr('foot_note')

        $.get(`/cms/foot_notes/${footnoteId}.json`, {}).then(function (data) {
          $("<div>").html(data.text).addClass(`${data.language_name} footnote-dialog`).appendTo("body").dialog()
        })
      })
    }
  }
}

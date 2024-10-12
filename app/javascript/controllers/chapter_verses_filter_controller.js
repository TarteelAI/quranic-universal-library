import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.el = $(this.element)
    this.chapterSelect = this.el.find("#chapter-select");
    this.verseSelect = this.el.find("#verse-select");

    if(this.verseSelect.length > 0)
      this.chapterSelect.on("change", this.updateVerseOptions.bind(this));
  }

  updateVerseOptions(event) {
    const selectedOption = this.chapterSelect.find(":selected");
    const versesCount = selectedOption.data("verses") || 286;
    this.clearVerseOptions();

    for (let i = 1; i <= versesCount; i++) {
      const option = document.createElement("option");
      option.value = i;
      option.text = i;
      this.verseSelect.append(option);
    }
  }

  clearVerseOptions() {
    this.verseSelect.find('option[value!=""]').remove()
  }
}

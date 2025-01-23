// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element)
    this.filter = this.el.find("#search-input")
    this.ayahs = this.el.find("#ayahs")

    this.filter.on("change", this.filterAyah.bind(this))
  }

  filterAyah(event){
    const filter = this.filter.val();
    if(filter.length === 0) {
      this.ayahs.find("[data-ayah]").each((index, ayah) => {
        ayah.classList.remove("d-none")
      })
      return
    }

    this.ayahs.find("[data-ayah]").each((index, ayah) => {
      const text = ayah.dataset.ayah;

      if (text === filter) {
        ayah.classList.remove("d-none")
      } else {
        ayah.classList.add("d-none")
      }
    })
  }
}

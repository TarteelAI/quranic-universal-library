import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element)
    this.addThemeButtons()
    this.bindEvents()
  }

  addThemeButtons() {
    const light = "<button class='btn btn-sm btn-primary' data-theme='theme-light'>Light</button>"
    const dark = "<button class='btn btn-sm btn-primary' data-theme='theme-dark'>Dark</button>"
    const sepia = "<button class='btn btn-sm btn-primary' data-theme='theme-sepia'>Sepia</button>"
    const black = "<button class='btn btn-sm btn-primary' data-theme='theme-black-text'>Black</button>"
    const light2 = "<button class='btn btn-sm btn-primary' data-theme='theme-light2'>L2</button>"
    const dark2 = "<button class='btn btn-sm btn-primary' data-theme='theme-dark2'>D2</button>"
    const sepia2 = "<button class='btn btn-sm btn-primary' data-theme='theme-sepia2'>S2</button>"

    this.el.append(`<div>${light} ${light2} ${dark} ${dark2} ${sepia} ${sepia2} ${black}</div>`)
  }

  bindEvents(){
    this.el.find('[data-theme]').on('click', (e) => {
      this.el.removeClass("theme-light theme-dark theme-sepia theme-light2 theme-dark2 theme-sepia2 theme-black-text")
      this.el.addClass(e.target.dataset.theme)
    })
  }
}

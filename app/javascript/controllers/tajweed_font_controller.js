import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element)
    this.addThemeButtons()
    this.bindEvents()
  }

  addThemeButtons() {
    const light = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme-light'>Light</button>"
    const dark = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme-dark'>Dark</button>"
    const sepia = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme-sepia'>Sepia</button>"
    const black = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme-black'>Black</button>"

    const p1 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme1'>P1</button>"
    const p2 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme2'>P2</button>"
    const p3 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme3'>P3</button>"
    const p4 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme4'>P4</button>"
    const p5 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme5'>P5</button>"
    const p6 = "<button class='tw-btn tw-btn-sm tw-btn-info' data-theme='theme6'>P6</button>"

    this.el.append(`<div>${light} ${dark} ${sepia} ${black} ${p1} ${p2} ${p3} ${p4} ${p5} ${p6}</div>`)
  }

  bindEvents(){
    this.el.find('[data-theme]').on('click', (e) => {
      const theme = e.target.dataset.theme;
      this.el.removeClass("theme-light theme-dark theme-sepia theme-black theme-normal theme1 theme2 theme3 theme4 theme5 theme6")
      this.el.addClass(theme);
    })
  }
}

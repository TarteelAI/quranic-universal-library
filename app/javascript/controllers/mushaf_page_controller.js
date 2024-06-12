import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const el = $(this.element);
    const ayahs = el.find(".page .ayah");
    const words = el.find(".page .ayah .char");
    const fontSwitcher = el.find('select#change_font')
    const mushtabiat = el.find('#mushtabiat')

    mushtabiat.on("change", (event) => {
      const url = window.location.href;
      const urlWithQuery = new URL(url);

      let showMushtabiat = urlWithQuery.searchParams.get('mushtabiat');
      showMushtabiat = showMushtabiat !== '0'  ? 1 : 0
      urlWithQuery.searchParams.set('mushtabiat', showMushtabiat);

      window.location.href = urlWithQuery.href;
    })

    if(fontSwitcher.length >0){
      fontSwitcher.on('change', this.changeFont.bind(this))
    }

    ayahs.on('mouseover', (event) => {
      const ayah = event.currentTarget.dataset.ayah;
      $(`[data-ayah=${ayah}]`).addClass('highlight bg-success-50')
    });

    ayahs.on('mouseout', (event) => {
      const ayah = event.currentTarget.dataset.ayah;
      $(`[data-ayah=${ayah}]`).removeClass('highlight bg-success-50')
    });

    words.on('mouseover', (event) => {
      const wordId = event.currentTarget.dataset.wordId;
      $(`[data-word-id=${wordId}]`).addClass('highlight bg-info-50')
    });

    words.on('mouseout', (event) => {
      const wordId = event.currentTarget.dataset.wordId;
      $(`[data-word-id=${wordId}]`).removeClass('highlight bg-info-50')
    });

    el.find('.font-size-slider').on('change', (event) => {
      const fontSize = event.target.value;

      el.find('.char').css('font-size', `${fontSize}px`)
      el.find('#size').html(`${fontSize}px`)
    })

    this.el = el;
  }

  changeFont(e){
    const font = e.target.value;
    this.el.removeClass().addClass(`mushaf mushaf-${font}`)
  }
}

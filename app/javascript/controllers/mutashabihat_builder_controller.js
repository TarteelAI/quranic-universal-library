import {Controller} from "@hotwired/stimulus"
import LocalStore from "../utils/LocalStore";

export default class extends Controller {
  connect() {
    this.store = new LocalStore();
    this.el = $(this.element)
    this.addAyah = this.el.find('#add_ayah_key')

    this.el.on('click', "[data-action=add]", this.addWord.bind(this))
    this.el.on('click', "[data-action=remove]", this.removeWord.bind(this))
    this.el.on('click',"[data-action=savePhrase]", this.savePhrase.bind(this))
    this.el.on('click',"[data-action=resetSelection]", this.resetSelection.bind(this))
    this.el.on('click', "[data-action=removePhrase]", this.removePhrase.bind(this))
    this.el.on('click', "[data-action=bookmark]", this.toggleBookmark.bind(this))
    this.el.on('change', "#add_ayah_key", this.suggestNewAyah.bind(this))

    this.updateBookmarks()
  }

  updateBookmarks() {
    this.bookmarks = JSON.parse(this.store.get('bookmarks') || "{}")

    Object.keys(this.bookmarks).forEach((key) => {
      const ayahDom = this.el.find(`[ data-ayahkey='${key}']`);
      if(ayahDom)
        ayahDom.find('[data-action=bookmark]').addClass('btn-success').removeClass('btn-outline-success')
    })
  }

  suggestNewAyah(event) {
    var csrfToken = $('meta[name="csrf-token"]').attr('content');
    const options = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      }
    }
    const key = $(event.target).val();
    fetch(`/morphology_phrases/new?add_ayah_key=${key}`, options)
      .then(r => r.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
  }

  toggleBookmark(event) {
    const target = $(event.currentTarget)
    const ayahKey = target.closest('.ayah').data('ayahkey')

    if (this.bookmarks[ayahKey]) {
      delete this.bookmarks[ayahKey]
      target.removeClass('btn-success').addClass('btn-outline-success')
    } else {
      this.bookmarks[ayahKey] = true
      target.addClass('btn-success').removeClass('btn-outline-success')
    }

    this.store.set('bookmarks', JSON.stringify(this.bookmarks))
  }

  resetSelection(event){
    const ayah = $(event.target).closest('.ayah');
    ayah.find('.word').removeClass('selected');
    ayah.find('[data-action=add]').removeClass('active');
  }

  savePhrase(event) {
    const data = this.preparePhraseData(event);
    var csrfToken = $('meta[name="csrf-token"]').attr('content');

    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify(data)
    }

    fetch("/morphology_phrases", options)
      .then(r => r.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
  }

  removePhrase(event) {
    if(confirm('Are you sure you want to delete this phrase?') == false)
      return;
    
    const data = this.preparePhraseData(event);
    var csrfToken = $('meta[name="csrf-token"]').attr('content');

    const options = {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify(data)
    }

    fetch("/morphology_phrases/dummy", options)
      .then(r => r.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
  }

  addWord(event) {
    const wordDom = $(event.target).closest('.word')
    const selected = wordDom.hasClass('selected')

    if (selected) {
      wordDom.removeClass('selected')
      wordDom.find("[data-action=add]").removeClass('active')
    } else {
      wordDom.addClass('selected')
      wordDom.find("[data-action=add]").addClass('active')
      wordDom.find("[data-action=remove]").removeClass('active')
    }
  }

  removeWord(event) {
    const wordDom = $(event.target).closest('.word')
    const selected = wordDom.hasClass('removed')

    if (selected) {
      wordDom.removeClass('selected')
      wordDom.find("[data-action=remove]").removeClass('active')
    } else {
      wordDom.addClass('selected')
      wordDom.find("[data-action=remove]").addClass('active')
      wordDom.find("[data-action=add]").removeClass('active')
    }
  }

  preparePhraseData(event) {
    const targetAyahDom = $(event.target).closest('.ayah')
    const wordsDom = targetAyahDom.find('.words')
    const ayah = targetAyahDom.data('ayahid')
    const selectedWords = wordsDom.find('[data-action="add"].active').map((i, w) => $(w).closest('.word').data('position')).get();
    const excludedWords = wordsDom.find('[data-action="remove"].active').map((i, w) => $(w).closest('.word').data('position')).get();

    return {
      phrase_text: this.el.find('#text').val(),
      verse_id: ayah,
      source_ayah_key: this.el.find('#source_ayah').val(),
      source_ayah_word_from: this.el.find('.word-from').val(),
      source_ayah_word_to: this.el.find('.word-to').val(),
      phrase_id: this.el.find('#phrase_id').val(),
      selected_words: selectedWords.join(','),
      excluded_words: excludedWords.join(',')
    }
  }
}

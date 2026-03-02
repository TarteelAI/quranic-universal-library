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
    ayah.find('.word').removeClass('selected removed');
    ayah.find('[data-action=add]').removeClass('active tw-bg-green-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200');
    ayah.find('[data-action=remove]').removeClass('active tw-bg-red-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200');
    ayah.find('.quran-text').removeClass('tw-text-green-600 tw-font-bold tw-text-red-400 tw-line-through');
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
    const isShiftClick = event.shiftKey
    const currentPosition = parseInt(wordDom.data('position'))
    const ayahId = wordDom.closest('.ayah').data('ayahid')

    this.lastWordAction = this.lastWordAction || {}

    if (isShiftClick && this.lastWordAction.ayahId === ayahId && this.lastWordAction.action === 'add') {
      const start = Math.min(this.lastWordAction.position, currentPosition)
      const end = Math.max(this.lastWordAction.position, currentPosition)
      
      wordDom.closest('.ayah').find('.word').each((i, el) => {
        const pos = parseInt($(el).data('position'))
        if (pos >= start && pos <= end) {
          this.toggleWordState($(el), 'add', true)
        }
      })
    } else {
      this.toggleWordState(wordDom, 'add')
    }

    this.lastWordAction = { ayahId, position: currentPosition, action: 'add' }
  }

  removeWord(event) {
    const wordDom = $(event.target).closest('.word')
    const isShiftClick = event.shiftKey
    const currentPosition = parseInt(wordDom.data('position'))
    const ayahId = wordDom.closest('.ayah').data('ayahid')

    this.lastWordAction = this.lastWordAction || {}

    if (isShiftClick && this.lastWordAction.ayahId === ayahId && this.lastWordAction.action === 'remove') {
      const start = Math.min(this.lastWordAction.position, currentPosition)
      const end = Math.max(this.lastWordAction.position, currentPosition)
      
      wordDom.closest('.ayah').find('.word').each((i, el) => {
        const pos = parseInt($(el).data('position'))
        if (pos >= start && pos <= end) {
          this.toggleWordState($(el), 'remove', true)
        }
      })
    } else {
      this.toggleWordState(wordDom, 'remove')
    }

    this.lastWordAction = { ayahId, position: currentPosition, action: 'remove' }
  }

  toggleWordState(wordDom, actionType, forceEnable = false) {
    const addIcon = wordDom.find("[data-action=add]")
    const removeIcon = wordDom.find("[data-action=remove]")
    const textSpan = wordDom.find(".quran-text")

    if (actionType === 'add') {
      const selected = wordDom.hasClass('selected')
      if (selected && !forceEnable) {
        wordDom.removeClass('selected')
        addIcon.removeClass('active tw-bg-green-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        textSpan.removeClass('tw-text-green-600 tw-font-bold')
      } else {
        wordDom.addClass('selected').removeClass('removed')
        addIcon.addClass('active tw-bg-green-500 tw-text-white').removeClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        removeIcon.removeClass('active tw-bg-red-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        textSpan.addClass('tw-text-green-600 tw-font-bold').removeClass('tw-text-red-400 tw-line-through')
      }
    } else if (actionType === 'remove') {
      const removed = wordDom.hasClass('removed')
      if (removed && !forceEnable) {
        wordDom.removeClass('removed')
        removeIcon.removeClass('active tw-bg-red-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        textSpan.removeClass('tw-text-red-400 tw-line-through')
      } else {
        wordDom.addClass('removed').removeClass('selected')
        removeIcon.addClass('active tw-bg-red-500 tw-text-white').removeClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        addIcon.removeClass('active tw-bg-green-500 tw-text-white').addClass('tw-bg-white tw-text-slate-400 tw-border tw-border-slate-200')
        textSpan.addClass('tw-text-red-400 tw-line-through').removeClass('tw-text-green-600 tw-font-bold')
      }
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

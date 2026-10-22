import {Controller} from "@hotwired/stimulus"

// Source phrase bar of the Mutashabihat builder. Picking a new source ayah,
// or clicking the first and last word of the source phrase, searches again.
// Each ayah card is handled by the mutashabihat-ayah controller.
export default class extends Controller {
  static targets = ["form", "sourceWord", "wordFrom", "wordTo", "hint", "bar", "sentinel"]

  connect() {
    this.anchor = null
    this.el = $(this.element)

    // select2 fires jQuery change events, not native ones
    this.el.on('change.mutashabihat', '#add_ayah_key', this.suggestNewAyah.bind(this))
    this.el.on('change.mutashabihat', '#source_ayah', this.changeSourceAyah.bind(this))

    this.watchStuck()
  }

  disconnect() {
    this.el.off('.mutashabihat')
    if (this.onScroll) window.removeEventListener('scroll', this.onScroll)
  }

  // Once the source bar is pinned while scrolling, shrink it to just the
  // selected words so it doesn't cover the ayahs.
  watchStuck() {
    if (!this.hasSentinelTarget || !this.hasBarTarget) return

    this.onScroll = () => {
      if (this.scrollFrame) return

      this.scrollFrame = requestAnimationFrame(() => {
        this.scrollFrame = null
        const pinned = this.sentinelTarget.getBoundingClientRect().top < 76
        this.barTarget.classList.toggle('is-stuck', pinned && this.anchor === null)
      })
    }

    window.addEventListener('scroll', this.onScroll, {passive: true})
    this.onScroll()
  }

  pickSourceWord(event) {
    const position = parseInt(event.currentTarget.dataset.position)

    if (this.anchor === null) {
      this.anchor = position
      this.barTarget?.classList.remove('is-stuck')
      this.sourceWordTargets.forEach((w) => {
        w.classList.remove('is-selected', 'range-start', 'range-end')
        w.classList.toggle('is-anchor', parseInt(w.dataset.position) === position)
      })
      if (this.hasHintTarget) this.hintTarget.textContent = 'Now click the last word of the phrase'
      return
    }

    this.wordFromTarget.value = Math.min(this.anchor, position)
    this.wordToTarget.value = Math.max(this.anchor, position)
    this.search()
  }

  changeSourceAyah() {
    // New ayah, let the server pick the full ayah as the phrase
    this.wordFromTarget.value = ''
    this.wordToTarget.value = ''
    this.search()
  }

  search() {
    if (this.hasHintTarget) this.hintTarget.textContent = 'Searching...'
    this.formTarget.requestSubmit()
  }

  filter(event) {
    const selected = event.currentTarget.dataset.filter

    this.element.querySelectorAll('[data-filter]').forEach((b) => b.classList.toggle('is-active', b === event.currentTarget))
    this.element.querySelectorAll('#suggested-ayahs .ayah').forEach((card) => {
      const categories = (card.dataset.categories || '').split(' ')
      card.classList.toggle('hidden', selected !== 'all' && !categories.includes(selected))
    })
  }

  suggestNewAyah(event) {
    const key = $(event.target).val()
    if (!key) return

    const params = new URLSearchParams({
      add_ayah_key: key,
      source_ayah: this.element.querySelector('#source_ayah')?.value || '',
      word_from: this.wordFromTarget.value,
      word_to: this.wordToTarget.value
    })

    fetch(`/morphology_phrases/new?${params}`, {
      headers: {Accept: "text/vnd.turbo-stream.html"}
    })
      .then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))
  }
}

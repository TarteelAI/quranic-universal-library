import {Controller} from "@hotwired/stimulus"
import LocalStore from "../utils/LocalStore";

// One suggested ayah in the Mutashabihat builder.
//
// Click the first word and then the last word to select a range. An ayah can
// have more than one range, since the same phrase can appear twice in it.
// Clicking a word inside a selected range excludes it (a word that differs
// from the phrase), clicking it again includes it back.
export default class extends Controller {
  static targets = ["word", "ranges", "bookmark", "saveButton"]
  static values = {
    ranges: Array,
    excluded: Array,
    editable: Boolean,
    saved: Boolean
  }

  connect() {
    this.store = new LocalStore()
    this.anchor = null
    this.ranges = this.rangesValue.map(([from, to]) => [Math.min(from, to), Math.max(from, to)])
    this.excluded = new Set(this.excludedValue.map(Number))
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener('keydown', this.onKeydown)

    this.render()
    this.renderBookmark()
  }

  disconnect() {
    document.removeEventListener('keydown', this.onKeydown)
  }

  pick(event) {
    if (!this.editableValue) return

    const position = parseInt(event.currentTarget.dataset.position)

    if (this.anchor !== null) {
      this.addRange(this.anchor, position)
      this.anchor = null
    } else if (this.rangeIndexFor(position) > -1) {
      this.excluded.has(position) ? this.excluded.delete(position) : this.excluded.add(position)
    } else {
      this.anchor = position
    }

    this.markDirty()
    this.render()
  }

  removeRange(event) {
    const [from, to] = this.ranges[parseInt(event.currentTarget.dataset.index)]
    this.ranges = this.ranges.filter(([f, t]) => f !== from || t !== to)
    this.excluded.forEach((p) => { if (p >= from && p <= to) this.excluded.delete(p) })

    this.markDirty()
    this.render()
  }

  useRanges(event) {
    this.ranges = JSON.parse(event.currentTarget.dataset.ranges)
    this.excluded.forEach((p) => { if (this.rangeIndexFor(p) === -1) this.excluded.delete(p) })
    this.anchor = null

    this.markDirty()
    this.render()
  }

  clear() {
    this.ranges = []
    this.excluded.clear()
    this.anchor = null

    this.markDirty()
    this.render()
  }

  onKeydown(event) {
    if (event.key === 'Escape' && this.anchor !== null) {
      this.anchor = null
      this.render()
    }
  }

  addRange(a, b) {
    let from = Math.min(a, b)
    let to = Math.max(a, b)

    // Merge with any range it overlaps
    const kept = []
    this.ranges.forEach(([f, t]) => {
      if (f <= to && t >= from) {
        from = Math.min(from, f)
        to = Math.max(to, t)
      } else {
        kept.push([f, t])
      }
    })

    kept.push([from, to])
    this.ranges = kept.sort((x, y) => x[0] - y[0])
  }

  rangeIndexFor(position) {
    return this.ranges.findIndex(([from, to]) => position >= from && position <= to)
  }

  excludedInRanges() {
    return [...this.excluded].filter((p) => this.rangeIndexFor(p) > -1).sort((a, b) => a - b)
  }

  render() {
    this.wordTargets.forEach((word) => {
      const position = parseInt(word.dataset.position)
      const range = this.ranges[this.rangeIndexFor(position)]

      word.classList.toggle('is-selected', !!range)
      word.classList.toggle('is-excluded', !!range && this.excluded.has(position))
      word.classList.toggle('range-start', !!range && range[0] === position)
      word.classList.toggle('range-end', !!range && range[1] === position)
      word.classList.toggle('is-anchor', this.anchor === position)
    })

    this.renderRanges()
  }

  renderRanges() {
    if (!this.hasRangesTarget) return

    const chips = this.ranges.map(([from, to], index) => {
      const label = from === to ? `${from}` : `${from}–${to}`
      const remove = this.editableValue
        ? `<button type="button" class="range-chip-remove" data-index="${index}" data-action="mutashabihat-ayah#removeRange" aria-label="Remove range ${label}">&times;</button>`
        : ''

      return `<span class="range-chip">${label}${remove}</span>`
    })

    if (this.anchor !== null) {
      chips.push(`<span class="range-chip is-pending">${this.anchor}–? <span class="opacity-70">click last word, Esc to cancel</span></span>`)
    } else if (chips.length === 0) {
      chips.push(`<span class="text-xs text-slate-400">No words selected</span>`)
    }

    this.rangesTarget.innerHTML = chips.join('')
  }

  markDirty() {
    if (this.hasSaveButtonTarget) this.saveButtonTarget.classList.add('is-dirty')
  }

  save() {
    this.request('POST', '/morphology_phrases', {
      ...this.sourceParams(),
      verse_id: this.element.dataset.ayahid,
      ranges: JSON.stringify(this.ranges),
      excluded_words: this.excludedInRanges().join(',')
    })
  }

  remove() {
    const phraseId = this.sourceParams().phrase_id

    if (!this.savedValue || !phraseId) {
      this.element.remove()
      return
    }

    if (!confirm(`Remove ${this.element.dataset.ayahkey} from this phrase?`)) return

    this.request('DELETE', '/morphology_phrases/ayah', {
      phrase_id: phraseId,
      verse_id: this.element.dataset.ayahid
    })
  }

  sourceParams() {
    const value = (id) => document.getElementById(id)?.value

    return {
      phrase_text: value('text'),
      source_ayah_key: value('source_ayah'),
      source_ayah_word_from: value('word_from'),
      source_ayah_word_to: value('word_to'),
      phrase_id: value('phrase_id')
    }
  }

  request(method, url, data) {
    fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        Accept: "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify(data)
    })
      .then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))
  }

  bookmarks() {
    try {
      return JSON.parse(this.store.get('bookmarks') || "{}")
    } catch (e) {
      return {}
    }
  }

  toggleBookmark() {
    const bookmarks = this.bookmarks()
    const key = this.element.dataset.ayahkey

    bookmarks[key] ? delete bookmarks[key] : bookmarks[key] = true
    this.store.set('bookmarks', JSON.stringify(bookmarks))
    this.renderBookmark()
  }

  renderBookmark() {
    if (!this.hasBookmarkTarget) return

    const active = !!this.bookmarks()[this.element.dataset.ayahkey]
    this.bookmarkTarget.classList.toggle('is-active', active)
  }
}

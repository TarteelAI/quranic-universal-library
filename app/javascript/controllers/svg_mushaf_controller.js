import { Controller } from "@hotwired/stimulus"

const SVG_NS = "http://www.w3.org/2000/svg"

const COLORS = {
  ayah: "#5EEAD4",
  sequence: "#0F766E",
  line: "#FBBF24",
  lineOpacity: "0.45",
  word: "#7C3AED",
  search: "#EA580C",
  diacriticHighlight: "#2563EB",
  waqfHighlight: "#C026D3"
}

const MARGIN_IDS = {
  surah: "md-non-quranic-header-surah-name",
  juz: "md-non-quranic-header-juz-name",
  pageNumber: "md-non-quranic-page-number",
  hizb: "md-non-quranic-margin-juz-hisb",
  sajda: "md-non-quranic-margin-sajda"
}

export default class extends Controller {
  static targets = [
    "svgHost",
    "wordInput",
    "multiWordInput",
    "searchInput",
    "matchCount",
    "ayahList"
  ]

  connect() {
    this.svg = this.svgHostTarget.querySelector("svg")
    this.wordNodes = []
    this.ayahWords = new Map()
    this.blobCache = new WeakMap()
    this._ayahClick = this.onAyahListClick.bind(this)

    this.state = {
      line: null,
      ayah: null,
      search: "",
      wordIds: [],
      showDiacritics: true,
      highlightDiacritics: false,
      showWaqf: true,
      waqfHighlight: false,
      margins: {
        surah: true,
        juz: true,
        pageNumber: true,
        hizb: true,
        sajda: true
      }
    }

    this.cache = {
      original: new WeakMap(),
      word: new Set(),
      search: new Set(),
      ayah: new Set(),
      waqf: new Set()
    }

    this.sequence = {
      timer: null,
      words: [],
      index: -1,
      prevWord: null
    }

    if (this.svg) {
      this.ensureOverlay()
      this.indexWords()
      this.buildAyahList()
      if (this.hasAyahListTarget) {
        this.ayahListTarget.addEventListener("click", this._ayahClick)
      }
      this.refresh()
    }
  }

  disconnect() {
    this.stopSequence(false)
    if (this.hasAyahListTarget) {
      this.ayahListTarget.removeEventListener("click", this._ayahClick)
    }
  }

  toggleState(event) {
    const key = event.params?.key || event.currentTarget?.dataset?.key
    if (key == null || this.state[key] === undefined) return
    this.state[key] = !this.state[key]
    this.refresh()
  }

  stopSequenceClick() {
    this.stopSequence(true)
  }

  toggleMargin(e) {
    const k = e.currentTarget.dataset.marginKey
    if (!k || this.state.margins[k] === undefined) return
    this.state.margins[k] = !this.state.margins[k]
    this.applyMargins()
  }

  onAyahListClick(e) {
    const btn = e.target.closest("[data-surah][data-ayah]")
    if (!btn) return
    const surah = Number(btn.dataset.surah)
    const ayah = Number(btn.dataset.ayah)
    this.applyAyahSelection(surah, ayah)
  }

  applyAyahSelection(surah, ayah) {
    this.stopSequence(false)
    const same =
      this.state.ayah &&
      this.state.ayah.surah === surah &&
      this.state.ayah.ayah === ayah
    this.state.ayah = same ? null : { surah, ayah }
    this.refresh()
    if (this.state.ayah) {
      this.startSequence(this.state.ayah.surah, this.state.ayah.ayah)
    }
  }

  selectLine(e) {
    const n = Number(e.currentTarget.dataset.line)
    this.state.line = this.state.line === n ? null : n
    this.refresh()
  }

  applyLine() {
    if (!this.state.line) return
    const id = `md-line-${String(this.state.line).padStart(2, "0")}`
    const node = this.svg.getElementById(id)
    if (!node) return
    const box = node.getBBox()
    const rect = document.createElementNS(SVG_NS, "rect")
    rect.setAttribute("x", String(box.x - 1.5))
    rect.setAttribute("y", String(box.y - 1.5))
    rect.setAttribute("width", String(box.width + 3))
    rect.setAttribute("height", String(box.height + 3))
    rect.setAttribute("rx", "2")
    rect.setAttribute("fill", COLORS.line)
    rect.setAttribute("fill-opacity", COLORS.lineOpacity)
    rect.setAttribute("pointer-events", "none")
    this.overlay.appendChild(rect)
  }

  ayahAttr(w) {
    return w.getAttribute("data-aya") || w.getAttribute("data-ayah")
  }

  ayahKey(surah, ayah) {
    const s = String(Number(surah)).padStart(3, "0")
    const a = String(Number(ayah)).padStart(3, "0")
    return `${s}|${a}`
  }

  indexWords() {
    this.wordNodes = this.words()
    this.ayahWords.clear()
    for (const w of this.wordNodes) {
      const s = w.getAttribute("data-surah")
      const a = this.ayahAttr(w)
      if (!s || a == null || a === "") continue
      const key = this.ayahKey(s, a)
      if (!this.ayahWords.has(key)) this.ayahWords.set(key, [])
      this.ayahWords.get(key).push(w)
    }
    for (const [, list] of this.ayahWords) {
      list.sort(
        (a, b) =>
          Number(a.getAttribute("data-word-index-in-ayah") || 0) -
          Number(b.getAttribute("data-word-index-in-ayah") || 0)
      )
    }
  }

  wordsForAyah(surah, ayah) {
    return this.ayahWords.get(this.ayahKey(surah, ayah)) || []
  }

  buildAyahList() {
    if (!this.hasAyahListTarget) return
    const rows = []
    const keys = [...this.ayahWords.keys()].sort((a, b) => {
      const [as, aa] = a.split("|").map(Number)
      const [bs, ba] = b.split("|").map(Number)
      return as !== bs ? as - bs : aa - ba
    })
    for (const key of keys) {
      const [surah, ayah] = key.split("|")
      const label = `${Number(surah)}:${Number(ayah)}`
      rows.push(
        `<button type="button" class="tw-rounded-lg tw-border tw-border-slate-200 tw-bg-white tw-px-2.5 tw-py-1.5 tw-text-xs tw-font-medium tw-text-slate-700 hover:tw-bg-slate-50 tw-min-w-[3rem]" data-surah="${surah}" data-ayah="${ayah}">${label}</button>`
      )
    }
    this.ayahListTarget.innerHTML = rows.join("")
  }

  applyAyah() {
    if (!this.state.ayah) return
    const words = this.wordsForAyah(this.state.ayah.surah, this.state.ayah.ayah)
    for (const w of words) {
      this.paint(w, COLORS.ayah, this.cache.ayah)
    }
  }

  highlightWord() {
    const raw = this.wordInputTarget.value.trim()
    if (!raw) return
    const id = raw.replace(/^md-word-/, "").padStart(3, "0")
    this.state.wordIds = [id]
    this.refresh()
  }

  highlightMultipleWords() {
    const raw = this.multiWordInputTarget?.value || ""
    const ids = raw
      .split(",")
      .map(s => s.trim())
      .filter(Boolean)
      .map(id => id.replace(/^md-word-/, "").padStart(3, "0"))
    this.state.wordIds = ids
    this.refresh()
  }

  applyWordHighlights() {
    for (const id of this.state.wordIds) {
      const node = this.svg.getElementById(`md-word-${id}`)
      if (node) this.paint(node, COLORS.word, this.cache.word)
    }
  }

  search() {
    this.state.search = this.normalize(this.searchInputTarget.value)
    this.refreshSearchOnly()
  }

  clearSearch() {
    this.state.search = ""
    if (this.hasSearchInputTarget) this.searchInputTarget.value = ""
    for (const p of this.cache.search) {
      this.restore(p)
    }
    this.cache.search.clear()
    if (this.hasMatchCountTarget) this.matchCountTarget.textContent = ""
  }

  refreshSearchOnly() {
    for (const p of this.cache.search) {
      this.restore(p)
    }
    this.cache.search.clear()
    this.applySearch()
  }

  applySearch() {
    if (!this.state.search) {
      if (this.hasMatchCountTarget) this.matchCountTarget.textContent = ""
      return
    }
    const q = this.state.search
    const tokens = q.split(/\s+/).filter(Boolean)
    let count = 0
    const list = this.wordNodes

    if (tokens.length === 1) {
      const t = tokens[0]
      for (const w of list) {
        if (this.wordBlob(w).includes(t)) {
          this.paint(w, COLORS.search, this.cache.search)
          count++
        }
      }
    } else {
      const n = tokens.length
      for (let i = 0; i <= list.length - n; i++) {
        let ok = true
        for (let j = 0; j < n; j++) {
          if (this.wordBlob(list[i + j]) !== tokens[j]) {
            ok = false
            break
          }
        }
        if (ok) {
          count++
          for (let j = 0; j < n; j++) {
            this.paint(list[i + j], COLORS.search, this.cache.search)
          }
        }
      }
    }

    if (this.hasMatchCountTarget) {
      this.matchCountTarget.textContent = count ? `${count} matches` : "0 matches"
    }
  }

  wordBlob(w) {
    if (this.blobCache.has(w)) return this.blobCache.get(w)
    const hafs = w.getAttribute("data-hafs") || ""
    const imlaey = w.getAttribute("data-imlaey") || ""
    let text = ""
    w.querySelectorAll("path[data-text]").forEach(p => {
      text += " " + (p.getAttribute("data-text") || "")
    })
    const blob = this.normalize(`${hafs} ${imlaey} ${text}`)
    this.blobCache.set(w, blob)
    return blob
  }

  applyDiacritics() {
    const sel = "path[data-type='diacritic'], path[data-type='dots']"
    this.svg.querySelectorAll(sel).forEach(p => {
      this.capture(p)
      p.style.display = this.state.showDiacritics ? "" : "none"
      if (this.state.highlightDiacritics && this.state.showDiacritics) {
        p.style.fill = COLORS.diacriticHighlight
      } else {
        this.restore(p)
      }
    })
  }

  applyMargins() {
    for (const [marginKey, id] of Object.entries(MARGIN_IDS)) {
      const el = this.svg.getElementById(id)
      if (!el) continue
      this.capture(el)
      el.style.display = this.state.margins[marginKey] ? "" : "none"
    }
  }

  waqfNodes() {
    return this.svg.querySelectorAll(
      "path[data-type='waqf'], g[data-type='waqf'], path[data-waqf], g[data-waqf]"
    )
  }

  startSequence(surah, ayah) {
    this.stopSequence(false)
    const words = this.wordsForAyah(surah, ayah)
    if (!words.length) return
    this.sequence.words = words
    this.sequence.index = 0
    this.sequence.prevWord = null
    this.advanceSequenceFrame(true)
    this.sequence.timer = window.setInterval(() => {
      this.sequence.index++
      if (this.sequence.index >= this.sequence.words.length) {
        this.stopSequence(true)
        return
      }
      this.advanceSequenceFrame(false)
    }, 1000)
  }

  advanceSequenceFrame(isFirst) {
    const words = this.sequence.words
    const i = this.sequence.index
    if (!isFirst && this.sequence.prevWord) {
      this.paint(this.sequence.prevWord, COLORS.ayah, this.cache.ayah)
    }
    const w = words[i]
    this.paint(w, COLORS.sequence, this.cache.ayah)
    this.sequence.prevWord = w
  }

  stopSequence(runRefresh = false) {
    if (this.sequence.timer) {
      window.clearInterval(this.sequence.timer)
      this.sequence.timer = null
    }
    this.sequence.words = []
    this.sequence.index = -1
    this.sequence.prevWord = null
    if (runRefresh) this.refresh()
  }

  refresh() {
    if (!this.svg) return
    this.clearVisualLayers()
    this.applyMargins()
    this.applyDiacritics()
    this.applyWaqfLayer()
    this.applyLine()
    this.applyAyah()
    this.applyWordHighlights()
    this.applySearch()
  }

  applyWaqfLayer() {
    for (const p of this.cache.waqf) {
      this.restore(p)
    }
    this.cache.waqf.clear()
    const nodes = [...this.waqfNodes()]
    for (const node of nodes) {
      this.capture(node)
      node.style.display = this.state.showWaqf ? "" : "none"
    }
    if (this.state.waqfHighlight && this.state.showWaqf) {
      for (const node of nodes) {
        const paths =
          node.tagName === "path" ? [node] : [...node.querySelectorAll("path")]
        for (const p of paths) {
          this.capture(p)
          p.style.fill = COLORS.waqfHighlight
          this.cache.waqf.add(p)
        }
      }
    }
  }

  clearVisualLayers() {
    for (const p of this.cache.word) {
      this.restore(p)
    }
    this.cache.word.clear()

    for (const p of this.cache.ayah) {
      this.restore(p)
    }
    this.cache.ayah.clear()

    for (const p of this.cache.search) {
      this.restore(p)
    }
    this.cache.search.clear()

    while (this.overlay && this.overlay.firstChild) {
      this.overlay.removeChild(this.overlay.firstChild)
    }
  }

  words() {
    return Array.from(this.svg.querySelectorAll('g[id^="md-word-"]'))
  }

  paint(group, color, set) {
    group.querySelectorAll("path").forEach(p => {
      this.capture(p)
      p.style.fill = color
      set.add(p)
    })
  }

  capture(node) {
    if (this.cache.original.has(node)) return
    this.cache.original.set(node, {
      fill: node.style.fill || "",
      display: node.style.display || ""
    })
  }

  restore(node) {
    const o = this.cache.original.get(node)
    if (!o) return
    node.style.fill = o.fill
    node.style.display = o.display
  }

  normalize(s) {
    return (s || "")
      .normalize("NFC")
      .toLowerCase()
      .trim()
      .replace(/\s+/g, " ")
  }

  ensureOverlay() {
    const host = this.svg.querySelector("#md-page-inner") || this.svg
    let g = this.svg.querySelector("#md-line-overlay")
    if (!g) {
      g = document.createElementNS(SVG_NS, "g")
      g.setAttribute("id", "md-line-overlay")
      g.setAttribute("pointer-events", "none")
      host.appendChild(g)
    }
    this.overlay = g
  }
}

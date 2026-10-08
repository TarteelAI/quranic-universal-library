import { Controller } from "@hotwired/stimulus"
import { alignLetterTakes } from "../lib/letter_slices"
import { findRepeats, FULL, PARTIAL } from "../lib/segment_repeats"

export default class extends Controller {
  static targets = [
    "player", "playButton", "scrubber", "clock", "verses", "status",
    "liveToggle", "draftToggle", "lettersToggle", "followToggle",
    "draftLabel", "lettersLabel", "summary", "nextDiff",
    "counts", "showFilter", "filterNote", "approveAll", "rejectAll", "reviewNote", "emptyFilter"
  ]
  static values = { url: String, audioUrl: String, reviewUrl: String, reviewAllUrl: String }

  connect() {
    this.verses = []
    this.wordNodes = []   // { el, verseIndex, layer, from, to }
    this.letterNodes = []
    this.lastKey = ""
    this.playUntil = null   // set while playing one layer's range only
    this.diffVerses = new Set()    // verseIndex values that disagree
    this.rowsByVerse = new Map()   // verseIndex -> the row element
    this.repeatsByVerse = new Map()// verseIndex -> { kind, repeats }
    this.onTime = () => this.tick()
    this.onMeta = () => this.renderClock()
    this.playerTarget.addEventListener("timeupdate", this.onTime)
    this.playerTarget.addEventListener("loadedmetadata", this.onMeta)
    this.playerTarget.addEventListener("ended", () => this.setPlayLabel(false))
    this.load()
  }

  disconnect() {
    this.playerTarget.pause()
    this.playerTarget.removeEventListener("timeupdate", this.onTime)
    this.playerTarget.removeEventListener("loadedmetadata", this.onMeta)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  async load() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.verses = data.verses || []
      this.render(data)
    } catch (error) {
      this.statusTarget.textContent = `Could not load timings: ${error.message}`
    }
  }

  // ---- rendering ---------------------------------------------------------

  render(data) {
    const hasLive = this.verses.some((v) => v.live)
    const hasDraft = this.verses.some((v) => v.draft)
    const hasLiveLetters = this.verses.some((v) => v.live && (v.live.letters || []).length)
    const hasDraftLetters = this.verses.some((v) => v.draft && (v.draft.letters || []).length)

    this.liveToggleTarget.disabled = !hasLive
    this.draftToggleTarget.disabled = !hasDraft
    this.lettersToggleTarget.disabled = !(hasLiveLetters || hasDraftLetters)

    if (!hasLive) this.liveToggleTarget.checked = false
    if (!hasDraft) this.draftToggleTarget.checked = false

    const staged = this.verses.find((v) => v.draft)?.draft?.staged
    this.draftLabelTarget.textContent = hasDraft
      ? (staged ? `(staged drafts, ${data.source})` : `(not staged yet, ${data.source})`)
      : "(nothing to compare)"

    const letterNote = []
    if (hasLiveLetters) letterNote.push("live")
    if (hasDraftLetters) letterNote.push("draft")
    this.lettersLabelTarget.textContent = letterNote.length
      ? `(${letterNote.join(" + ")})`
      : "(no letter data)"

    this.versesTarget.replaceChildren()
    this.wordNodes = []
    this.letterNodes = []
    this.diffs = []

    if (!this.verses.length) {
      this.statusTarget.textContent = "No timings for this surah yet."
      return
    }
    this.statusTarget.classList.add("hidden")

    this.verses.forEach((verse, verseIndex) => {
      this.versesTarget.appendChild(this.verseRow(verse, verseIndex))
    })
    this.summarise(hasLive, hasDraft)
    this.redraw()
  }

  // Per word, how far apart the two layers put its boundaries. Without this the
  // page looks inert when the layers agree exactly (which they do whenever the
  // live segments were themselves imported from the same source) — "they agree
  // on all 58 words" is a real answer, not a blank screen.
  summarise(hasLive, hasDraft) {
    if (!hasLive || !hasDraft) {
      this.summaryTarget.textContent = hasLive
        ? "Nothing staged to compare against yet — only the live segments are shown."
        : "No live segments for this surah yet — only the draft is shown."
      this.nextDiffTarget.hidden = true
      return
    }

    let compared = 0
    let worst = 0

    this.verses.forEach((verse, verseIndex) => {
      const live = this.spanMap(verse.live)
      const draft = this.spanMap(verse.draft)
      const positions = new Set([...live.keys(), ...draft.keys()])

      positions.forEach((position) => {
        const a = live.get(position)
        const b = draft.get(position)
        compared++
        if (!a || !b) {
          this.diffs.push({ verseIndex, position, drift: Infinity, missing: true })
          return
        }
        const drift = Math.max(Math.abs(a[0] - b[0]), Math.abs(a[1] - b[1]))
        if (drift > this.constructor.DRIFT_TOLERANCE_MS) {
          this.diffs.push({ verseIndex, position, drift, missing: false })
          worst = Math.max(worst, drift)
        }
      })
    })

    this.diffs.sort((x, y) => x.verseIndex - y.verseIndex || x.position - y.position)
    this.diffVerses = new Set(this.diffs.map((diff) => diff.verseIndex))
    this.nextDiffTarget.hidden = this.diffs.length === 0
    this.diffIndex = -1

    this.summaryTarget.textContent = this.diffs.length === 0
      ? `Live and draft agree on all ${compared} word timings — play it to confirm the highlighting lands on the right words.`
      : `${this.diffs.length} of ${compared} words differ between live and draft (worst ${worst === 0 ? "—" : `${worst} ms`}).`
  }

  static DRIFT_TOLERANCE_MS = 1

  spanMap(layer) {
    const map = new Map()
    ;((layer || {}).words || []).forEach(([position, from, to]) => {
      if (!map.has(position)) map.set(position, [from, to])
    })
    return map
  }

  // Walk the disagreements: jump the audio to each one so you can hear it.
  nextDiff() {
    if (!this.diffs.length) return

    this.diffIndex = (this.diffIndex + 1) % this.diffs.length
    const diff = this.diffs[this.diffIndex]
    const verse = this.verses[diff.verseIndex]
    const span = this.spanMap(verse.draft).get(diff.position) || this.spanMap(verse.live).get(diff.position)
    if (!span) return

    // Start a moment early so the divergence is audible in context.
    this.playerTarget.currentTime = Math.max(0, (span[0] - 400) / 1000)
    this.nextDiffTarget.textContent =
      `Next difference (${this.diffIndex + 1}/${this.diffs.length}) · ${verse.key} word ${diff.position}`
    if (this.playerTarget.paused) this.togglePlay()
    else this.tick()
  }

  verseRow(verse, verseIndex) {
    const row = document.createElement("div")
    row.className = "border border-gray-200 rounded-lg px-3 py-2"
    row.dataset.verseIndex = String(verseIndex)

    const head = document.createElement("div")
    head.className = "flex items-center gap-2 text-xs text-gray-400 mb-1"

    const jump = document.createElement("button")
    jump.type = "button"
    jump.className = "px-1.5 py-0.5 rounded bg-gray-100 text-gray-600 hover:bg-gray-200"
    jump.textContent = "▶"
    jump.title = "Play on from this ayah"
    jump.addEventListener("click", () => this.playFrom(verse))
    head.appendChild(jump)

    const label = document.createElement("span")
    label.className = "font-medium text-gray-600"
    label.textContent = verse.key
    head.appendChild(label)

    // Each layer's range is its own play button: the two often differ, and the
    // only way to judge which is right is to hear each one on its own.
    head.appendChild(this.rangeChip("current", verse.live, "indigo"))
    head.appendChild(this.rangeChip("draft", verse.draft, "amber"))

    const repeat = this.repeatChip(verse, verseIndex)
    if (repeat) head.appendChild(repeat)
    head.appendChild(this.reviewControls(verse, verseIndex))
    row.appendChild(head)
    this.rowsByVerse.set(verseIndex, row)

    // One word row per enabled layer, so a disagreement shows as the two rows
    // lighting up different words at the same instant.
    row.appendChild(this.wordRow(verse, verseIndex, "live"))
    row.appendChild(this.wordRow(verse, verseIndex, "draft"))
    return row
  }

  // Where the reciter backed up and said something again. Read off the draft
  // when there is one — that is the layer being judged — otherwise off live, so
  // an ayah whose repeat only exists on one side is still findable.
  repeatChip(verse, verseIndex) {
    const layer = (verse.draft && (verse.draft.words || []).length) ? verse.draft : verse.live
    const words = (layer || {}).words || []
    const repeats = findRepeats(words, (verse.words || []).length)
    if (!repeats.length) return null

    const kind = repeats.some((r) => r.full) ? FULL : PARTIAL
    this.repeatsByVerse.set(verseIndex, { kind, repeats })

    const chip = document.createElement("button")
    chip.type = "button"
    chip.className = `px-1.5 py-0.5 rounded ${this.constructor.REPEAT_TONES[kind]}`
    chip.dataset.repeat = kind
    chip.textContent = `↻ ${repeats.map((r) => r.label).join(", ")}`
    chip.title = "Play from the repeat"
    chip.addEventListener("click", () => {
      const start = repeats.map((r) => r.startMs).filter((ms) => ms != null).sort((a, b) => a - b)[0]
      if (start != null) {
        this.playUntil = null
        this.seekTo(start)
      }
    })
    return chip
  }

  static REPEAT_TONES = {
    [FULL]: "bg-purple-100 text-purple-700 hover:bg-purple-200",
    [PARTIAL]: "bg-sky-100 text-sky-700 hover:bg-sky-200"
  }

  // Approve / reject / reset for one ayah, next to the ranges they apply to.
  // A draft that was never staged (the compare view can render what the current
  // artifacts WOULD stage) has no id, so there is nothing to review yet.
  reviewControls(verse, verseIndex) {
    const box = document.createElement("span")
    box.className = "ml-auto flex items-center gap-1"
    box.dataset.review = String(verseIndex)

    const draft = verse.draft
    if (!draft || !draft.id) {
      const hint = document.createElement("span")
      hint.className = "text-gray-300"
      hint.textContent = draft ? "not staged" : ""
      box.appendChild(hint)
      return box
    }

    const pill = document.createElement("span")
    pill.dataset.statusPill = "1"
    box.appendChild(pill)

    const button = (label, decision, cls) => {
      const el = document.createElement("button")
      el.type = "button"
      el.className = `px-1.5 py-0.5 rounded ${cls}`
      el.textContent = label
      el.dataset.decision = decision
      el.addEventListener("click", () => this.review(verseIndex, decision))
      box.appendChild(el)
      return el
    }

    button("Approve", "approve", "bg-gray-800 text-white hover:bg-gray-700")
    button("Reject", "reject", "bg-red-100 text-red-700 hover:bg-red-200")
    button("Reset", "reset", "bg-gray-100 text-gray-600 hover:bg-gray-200")

    this.paintStatus(box, draft.status)
    return box
  }

  // Which buttons make sense depends on where the draft already is: offering
  // "Approve" on an approved draft is a no-op that only costs a click to find out.
  paintStatus(box, status) {
    const pill = box.querySelector("[data-status-pill]")
    if (pill) {
      pill.className = `px-1.5 py-0.5 rounded font-medium ${this.constructor.STATUS_TONES[status] || this.constructor.STATUS_TONES.pending}`
      pill.textContent = status === "pending" || !status ? "to review" : status
    }

    box.querySelectorAll("[data-decision]").forEach((el) => {
      const decision = el.dataset.decision
      el.hidden = (decision === "approve" && status === "approved") ||
                  (decision === "reject" && status === "rejected") ||
                  (decision === "reset" && (status === "pending" || !status)) ||
                  status === "imported"
    })
  }

  static STATUS_TONES = {
    pending: "bg-gray-100 text-gray-600",
    approved: "bg-emerald-100 text-emerald-700",
    rejected: "bg-red-100 text-red-700",
    imported: "bg-indigo-100 text-indigo-700"
  }

  // The range readout doubles as the button that plays it — playback stops at
  // the range's end, so "current" and "draft" are actually distinguishable
  // instead of both running on into the rest of the surah.
  rangeChip(label, data, tone) {
    if (!data || data.from == null) {
      const empty = document.createElement("span")
      empty.className = "text-gray-300"
      empty.textContent = `no ${label}`
      return empty
    }

    const chip = document.createElement("button")
    chip.type = "button"
    chip.className = `tabular-nums px-1.5 py-0.5 rounded ${this.constructor.CHIP_TONES[tone]}`
    chip.dataset.playRange = label
    chip.textContent = `▶ ${label} ${(data.from / 1000).toFixed(2)}–${(data.to / 1000).toFixed(2)}s`
    chip.title = `Play just the ${label} range (${data.to - data.from} ms)`
    chip.addEventListener("click", () => this.playRange(data))
    return chip
  }

  wordRow(verse, verseIndex, layer) {
    const row = document.createElement("div")
    row.className = "digitalkhatt-v2 leading-loose flex flex-wrap gap-x-3 gap-y-1 justify-end py-1"
    row.dir = "rtl"
    row.dataset.layer = layer
    row.dataset.kind = "words"

    const timings = new Map()
    ;((verse[layer] || {}).words || []).forEach(([position, from, to]) => {
      // A repeated word appears twice; keep every span so both light up.
      if (!timings.has(position)) timings.set(position, [])
      timings.get(position).push([from, to])
    })

    const words = verse.words.length
      ? verse.words
      : [...timings.keys()].sort((a, b) => a - b).map((position) => ({ position, text: `#${position}` }))

    const lettersByWord = this.lettersByWord(verse[layer])

    words.forEach((word) => {
      const span = document.createElement("span")
      span.className = "px-1 rounded border-b-2 border-transparent transition-colors duration-75"
      span.title = `word ${word.position}`
      span.dataset.wordId = `${layer}-${verseIndex}-${word.position}`
      this.fillWord(span, word, lettersByWord[word.position], verseIndex, layer,
                    timings.get(word.position))
      row.appendChild(span)

      const spans = timings.get(word.position) || []
      if (spans.length) {
        spans.forEach(([from, to]) =>
          this.wordNodes.push({ el: span, verseIndex, layer, from, to, position: word.position }))
      } else {
        span.classList.add("opacity-30") // no timing on this layer for this word
      }
    })
    return row
  }

  // The word is either plain text, or — when this layer has letter timings that
  // align onto it — one .seg-letter span per letter, concatenating back to
  // exactly the same string.
  //
  // `occurrences` are the word's own spans: more than one means the reciter
  // repeated it, and each take gives the same slices another timing range.
  fillWord(span, word, letters, verseIndex, layer, occurrences) {
    const text = word.text || `#${word.position}`
    const slices = letters && letters.length ? alignLetterTakes(text, letters, occurrences) : null

    if (!slices) {
      span.textContent = text
      return
    }

    slices.forEach((slice, index) => {
      if (!slice.text) return

      const ranges = slice.ranges || [[slice.start, slice.end]]
      const cell = document.createElement("span")
      cell.className = "seg-letter"
      cell.textContent = slice.text
      cell.title = ranges
        .map(([from, to]) => `${(from / 1000).toFixed(3)}–${(to / 1000).toFixed(3)}s`)
        .join(", ")
      span.appendChild(cell)

      const id = `${layer}-${verseIndex}-${word.position}-${index}`
      ranges.forEach(([from, to]) => this.letterNodes.push({ el: cell, layer, from, to, id }))
    })
  }

  // word position => [{ char, start, end }], in reading order.
  lettersByWord(layer) {
    const map = {}
    ;((layer || {}).letters || []).forEach(([position, char, start, end]) => {
      ;(map[position] || (map[position] = [])).push({ char, start: Number(start), end: Number(end) })
    })
    return map
  }

  // ---- reviewing ---------------------------------------------------------
  //
  // Posting JSON instead of submitting a form is the whole point: the audio
  // keeps playing and the scroll position survives, so a reviewer can judge
  // ayah after ayah without the page going out from under them.

  async review(verseIndex, decision) {
    const verse = this.verses[verseIndex]
    const draft = verse && verse.draft
    if (!draft || !draft.id) return

    const url = this.reviewUrlValue.replace("DRAFT_ID", String(draft.id))
    const data = await this.post(url, { decision })
    if (!data) return

    draft.status = data.status
    const box = this.versesTarget.querySelector(`[data-review="${verseIndex}"]`)
    if (box) this.paintStatus(box, data.status)
    this.applyCounts(data.counts)
    this.reviewNoteTarget.textContent = `${verse.key}: ${data.status}.`
  }

  approveAll() { this.reviewAll("approve") }
  rejectAll() { this.reviewAll("reject") }

  // Bulk decisions only touch drafts nobody has judged yet (the server defaults
  // to scope=pending), so this can never quietly overturn an earlier rejection.
  async reviewAll(decision) {
    const pending = this.verses.filter((v) => v.draft && v.draft.id && v.draft.status === "pending")
    if (!pending.length) {
      this.reviewNoteTarget.textContent = "Nothing left unreviewed."
      return
    }

    const verb = decision === "approve" ? "Approve" : "Reject"
    if (!window.confirm(`${verb} ${pending.length} unreviewed ayah(s) in this surah?`)) return

    const data = await this.post(this.reviewAllUrlValue, { decision })
    if (!data) return

    pending.forEach((verse) => {
      verse.draft.status = data.status
      const index = this.verses.indexOf(verse)
      const box = this.versesTarget.querySelector(`[data-review="${index}"]`)
      if (box) this.paintStatus(box, data.status)
    })
    this.applyCounts(data.counts)
    this.reviewNoteTarget.textContent = `${data.changed} ayah(s) marked ${data.status}.`
  }

  async post(url, params) {
    const token = document.querySelector('meta[name="csrf-token"]')
    const body = new URLSearchParams(params)

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token ? token.content : ""
        },
        body
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return await response.json()
    } catch (error) {
      this.reviewNoteTarget.textContent = `Could not save: ${error.message}`
      return null
    }
  }

  applyCounts(counts) {
    if (!counts || !this.hasCountsTarget) return

    this.countsTarget.querySelectorAll("[data-count]").forEach((el) => {
      el.textContent = String(counts[el.dataset.count] || 0)
    })
  }

  // ---- toggles -----------------------------------------------------------

  redraw() {
    const showLive = this.liveToggleTarget.checked
    const showDraft = this.draftToggleTarget.checked

    this.versesTarget.querySelectorAll("[data-kind]").forEach((row) => {
      row.hidden = !(row.dataset.layer === "live" ? showLive : showDraft)
    })

    this.applyVerseFilter()
    this.lastKey = "" // force the next tick to repaint
    this.tick()
  }

  // Narrow a long surah to the ayahs worth looking at. On a surah imported from
  // the same source as the live segments nearly everything agrees, and the few
  // that matter — a disagreement, or somewhere the reciter backed up — are
  // otherwise buried in hundreds of identical rows.
  static FILTERS = {
    all: () => true,
    differ: (ctx, index) => ctx.diffVerses.has(index),
    repeat: (ctx, index) => ctx.repeatsByVerse.has(index),
    repeat_partial: (ctx, index) => ctx.repeatsByVerse.get(index)?.kind === PARTIAL,
    repeat_full: (ctx, index) => ctx.repeatsByVerse.get(index)?.kind === FULL
  }

  filterMode() {
    const value = this.hasShowFilterTarget ? this.showFilterTarget.value : "all"
    return this.constructor.FILTERS[value] ? value : "all"
  }

  applyVerseFilter() {
    const mode = this.filterMode()
    const keeps = this.constructor.FILTERS[mode]
    let shown = 0

    this.rowsByVerse.forEach((row, verseIndex) => {
      const keep = keeps(this, verseIndex)
      row.hidden = !keep
      if (keep) shown++
    })

    if (this.hasFilterNoteTarget) {
      this.filterNoteTarget.textContent = mode === "all"
        ? this.repeatSummary()
        : `Showing ${shown} of ${this.rowsByVerse.size} ayahs.`
    }
    if (this.hasEmptyFilterTarget) {
      this.emptyFilterTarget.hidden = !(mode !== "all" && shown === 0)
    }
  }

  repeatSummary() {
    const kinds = [...this.repeatsByVerse.values()].map((entry) => entry.kind)
    if (!kinds.length) return "No repeated words in this surah."

    const full = kinds.filter((kind) => kind === FULL).length
    const partial = kinds.length - full
    const parts = []
    if (full) parts.push(`${full} whole-ayah`)
    if (partial) parts.push(`${partial} partial`)
    return `${kinds.length} ayah(s) with a repeat (${parts.join(", ")}).`
  }

  // ---- playback ----------------------------------------------------------

  togglePlay() {
    if (this.playerTarget.paused) {
      // Pressing play again means "keep going", so drop any range boundary.
      if (this.playerTarget.currentTime * 1000 >= (this.playUntil ?? Infinity)) this.playUntil = null
      this.playerTarget.play().catch(() => {})
      this.setPlayLabel(true)
      this.pump()
    } else {
      this.playerTarget.pause()
      this.setPlayLabel(false)
    }
  }

  // Whichever layer starts EARLIER. Taking live whenever it exists skips any
  // audio only the draft covers — a repeated ayah, where the reciter backs up
  // and the live segments start at the second take, is exactly that audio.
  playFrom(verse) {
    const starts = [verse.live, verse.draft]
      .filter((data) => data && data.from != null)
      .map((data) => data.from)
    if (!starts.length) return

    this.playUntil = null
    this.seekTo(Math.min(...starts))
  }

  // One layer's range, and stop where it ends.
  playRange(data) {
    if (!data || data.from == null) return

    this.playUntil = data.to
    this.seekTo(data.from)
  }

  seekTo(ms) {
    this.playerTarget.currentTime = Math.max(0, ms / 1000)
    if (this.playerTarget.paused) this.togglePlay()
    else this.tick()
  }

  scrub() {
    const duration = this.playerTarget.duration
    if (!Number.isFinite(duration)) return

    this.playUntil = null
    this.playerTarget.currentTime = (this.scrubberTarget.value / 1000) * duration
    this.tick()
  }

  setPlayLabel(playing) {
    this.playButtonTarget.textContent = playing ? "⏸ Pause" : "▶ Play"
  }

  // timeupdate only fires ~4×/s, which looks laggy against word spans that are
  // often shorter than 300 ms; drive the paint off the frame clock while playing.
  pump() {
    if (this.playerTarget.paused) return

    this.tick()
    this.raf = requestAnimationFrame(() => this.pump())
  }

  tick() {
    const ms = this.playerTarget.currentTime * 1000
    this.renderClock()

    // Stop on the frame clock, not `timeupdate` — at ~4 events/s a range would
    // overrun by up to a quarter second, which is audible.
    if (this.playUntil != null && ms >= this.playUntil) {
      this.playUntil = null
      if (!this.playerTarget.paused) {
        this.playerTarget.pause()
        this.setPlayLabel(false)
      }
    }

    const showLive = this.liveToggleTarget.checked
    const showDraft = this.draftToggleTarget.checked
    const showLetters = this.lettersToggleTarget.checked

    // Keyed by verse+word, NOT by element: each layer renders its own row, so the
    // same word is two different elements. Comparing elements would mean the two
    // layers could never be seen to agree.
    const active = { live: new Set(), draft: new Set() }
    this.wordNodes.forEach((node) => {
      if (ms >= node.from && ms < node.to) active[node.layer].add(this.wordKey(node))
    })

    // Letters turn over several times inside one word, so they need their own
    // term in the repaint key — keyed on words alone, a letter change inside a
    // held word would never be drawn. Only walked when letters are on: a long
    // surah has tens of thousands of slices.
    const letters = new Set()
    if (showLetters) {
      this.letterNodes.forEach((node) => {
        if (ms >= node.from && ms < node.to) letters.add(node.id)
      })
    }

    // Repaint only when the highlighted set actually changed — this runs every
    // frame, and touching thousands of class lists 60×/s would drop frames on
    // a long surah.
    const key = `${showLive}|${showDraft}|${showLetters}|` +
      `${this.setKey(active.live)}|${this.setKey(active.draft)}|${this.setKey(letters)}`
    if (key === this.lastKey) return
    this.lastKey = key

    this.wordNodes.forEach((node) => this.paintWord(node, active, showLive, showDraft))
    this.paintLetters(letters, showLive, showDraft)
    this.follow(active)
  }

  // Written out as literal class strings, never interpolated: Tailwind only ships
  // the classes it can see as text in the source.
  // Written out in full: Tailwind scans the source text, so a class built by
  // interpolation (`bg-` + tone) is never generated and the chip renders bare.
  static CHIP_TONES = {
    indigo: "text-indigo-700 bg-indigo-50 hover:bg-indigo-100",
    amber: "text-amber-700 bg-amber-50 hover:bg-amber-100"
  }

  static TONES = {
    live: ["bg-indigo-100", "text-indigo-800", "border-indigo-500"],
    draft: ["bg-amber-100", "text-amber-800", "border-amber-500"],
    agreed: ["bg-emerald-100", "text-emerald-800", "border-emerald-500"]
  }

  wordKey(node) {
    return `${node.verseIndex}-${node.position}`
  }

  paintWord(node, active, showLive, showDraft) {
    const el = node.el
    const key = this.wordKey(node)
    const liveOn = showLive && active.live.has(key)
    const draftOn = showDraft && active.draft.has(key)
    const onThisRow = node.layer === "live" ? liveOn : draftOn

    const tones = this.constructor.TONES
    el.classList.remove(...tones.live, ...tones.draft, ...tones.agreed)
    el.classList.add("border-transparent")
    if (!onThisRow) return

    el.classList.remove("border-transparent")
    // Green means both layers agree this word is sounding right now; anything
    // else means they disagree, which is exactly what you came here to find.
    const tone = liveOn && draftOn ? tones.agreed : tones[node.layer]
    el.classList.add(...tone)
  }

  // Several letters can share one time range — a fatha and the superscript alef
  // above it are a single sound and are given identical timings — so every slice
  // covering the clock lights up, not just the first.
  paintLetters(active, showLive, showDraft) {
    this.letterNodes.forEach(({ el, layer, id }) => {
      const layerOn = layer === "live" ? showLive : showDraft
      el.classList.toggle("letter-active", layerOn && active.has(id))
    })
  }

  follow(active) {
    if (!this.followToggleTarget.checked) return

    const key = [...active.draft][0] || [...active.live][0]
    const node = key && this.wordNodes.find((n) => this.wordKey(n) === key)
    const row = node && node.el.closest("[data-verse-index]")
    if (!row || row === this.lastRow) return

    this.lastRow = row
    row.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  renderClock() {
    const current = this.playerTarget.currentTime
    const duration = this.playerTarget.duration
    this.clockTarget.textContent = `${current.toFixed(2)} / ${Number.isFinite(duration) ? duration.toFixed(2) : "0.00"}`
    if (Number.isFinite(duration) && duration > 0 && document.activeElement !== this.scrubberTarget) {
      this.scrubberTarget.value = String(Math.round((current / duration) * 1000))
    }
  }

  setKey(set) {
    return set.size ? [...set].sort().join(",") : ""
  }
}

import { Controller } from "@hotwired/stimulus"

// Listen to a QUL recitation and a QUD delivery side by side before attaching
// one to the other. Pick a recitation (or search for one), pick a surah, then
// play either file, or "Switch" to carry on from the same moment in the other
// one: the quickest way to hear whether they are the same recording.
export default class extends Controller {
  static targets = [
    "recitation", "search", "searchResults", "surah",
    "qulPlayer", "qudPlayer", "qulLabel", "qudLabel",
    "verdict", "status", "attachForm", "attachId", "attachButton", "previewLink"
  ]

  static values = { dataUrl: String, searchUrl: String, previewUrl: String, chapter: Number, attached: Boolean }

  connect() {
    this.qul = {}
    this.qud = {}
    this.drafts = new Set()
    if (this.recitationTarget.value) this.load()
  }

  // ---- picking ------------------------------------------------------------

  async load() {
    const id = this.recitationTarget.value
    this.pauseAll()
    if (!id) {
      this.qul = {}
      this.render()
      return
    }

    this.setStatus("Loading…")
    try {
      const response = await fetch(`${this.dataUrlValue}?recitation_id=${encodeURIComponent(id)}`, {
        headers: { Accept: "application/json" }
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`)

      this.recitation = data.recitation
      this.qul = data.qul || {}
      this.qud = data.qud || {}
      this.drafts = new Set((data.draft_chapters || []).map(String))
      this.verdict = data.verdict
      this.setStatus("")
      this.render()
    } catch (error) {
      this.setStatus(`Could not load: ${error.message}`)
    }
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.runSearch(), 250)
  }

  async runSearch() {
    const query = this.searchTarget.value.trim()
    if (query.length < 2) return

    try {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return
      const { recitations } = await response.json()

      const group = this.searchResultsTarget
      group.replaceChildren()
      ;(recitations || []).forEach((r) => {
        const option = document.createElement("option")
        option.value = r.id
        option.textContent = `#${r.id} ${r.name} · ${r.files_count || 0} files`
        group.appendChild(option)
      })
      group.label = recitations?.length ? `Search: "${query}"` : `Search: no match for "${query}"`
    } catch (error) {
      // Leave the list as it was; the search can be retried.
    }
  }

  // ---- rendering ----------------------------------------------------------

  render() {
    this.renderSurahs()
    this.renderVerdict()
    this.renderAttach()
    this.useSurah()
  }

  renderSurahs() {
    const current = this.surahTarget.value || String(this.chapterValue || 1)
    this.surahTarget.replaceChildren()
    for (let chapter = 1; chapter <= 114; chapter++) {
      const key = String(chapter)
      const notes = []
      if (!this.qul[key]) notes.push("no QUL audio")
      if (!this.qud[key]) notes.push("no QUD audio")
      if (!this.drafts.has(key)) notes.push("no drafts")
      const option = document.createElement("option")
      option.value = key
      option.textContent = notes.length ? `${chapter} (${notes.join(", ")})` : key
      this.surahTarget.appendChild(option)
    }
    this.surahTarget.value = current
  }

  renderVerdict() {
    if (!this.hasVerdictTarget) return
    const v = this.verdict
    this.verdictTarget.textContent = v && this.recitation ? v.text : ""
    const tone = { same_files: "text-emerald-700", same_recording: "text-emerald-700", different: "text-red-700" }
    this.verdictTarget.className = `text-xs ${(v && tone[v.kind]) || "text-gray-500"}`
  }

  renderAttach() {
    if (!this.hasAttachFormTarget) return
    const r = this.recitation && String(this.recitation.id) === this.recitationTarget.value ? this.recitation : null
    this.attachFormTarget.hidden = !r || this.attachedValue
    if (!r) return

    this.attachIdTarget.value = r.id
    this.attachButtonTarget.value = `Attach drafts to #${r.id} ${r.name}`
    const warnings = []
    if (r.qua_key) warnings.push(`It is already mapped to ${r.qua_key}.`)
    if (r.locked) warnings.push("Its segments are locked.")
    this.attachFormTarget.dataset.turboConfirm =
      [`Attach this delivery's drafts to #${r.id} ${r.name}?`, ...warnings].join(" ")
  }

  // Point both players at the chosen surah.
  useSurah() {
    this.pauseAll()
    const key = this.surahTarget.value
    this.setPlayer(this.qulPlayerTarget, this.qulLabelTarget, this.qul[key],
      this.recitation ? `QUL #${this.recitation.id} ${this.recitation.name}` : "QUL: pick a recitation")
    this.setPlayer(this.qudPlayerTarget, this.qudLabelTarget, this.qud[key], "QUD delivery (the file it timed)")

    if (this.hasPreviewLinkTarget) {
      const url = new URL(this.previewUrlValue, window.location.origin)
      url.searchParams.set("chapter_id", key)
      if (this.recitation) url.searchParams.set("recitation_id", this.recitation.id)
      this.previewLinkTarget.href = url.toString()
    }
  }

  setPlayer(player, label, src, title) {
    label.textContent = src ? title : `${title}: no audio for this surah`
    if (src) {
      if (player.getAttribute("src") !== src) player.src = src
      player.hidden = false
    } else {
      player.removeAttribute("src")
      player.load()
      player.hidden = true
    }
  }

  // ---- playback -----------------------------------------------------------

  // Only one plays at a time: two voices at once tell you little.
  played(event) {
    [this.qulPlayerTarget, this.qudPlayerTarget].forEach((p) => {
      if (p !== event.target) p.pause()
    })
  }

  // Carry on in the other file from the same moment.
  switch() {
    const [from, to] = this.qudPlayerTarget.paused && !this.qulPlayerTarget.paused
      ? [this.qulPlayerTarget, this.qudPlayerTarget]
      : !this.qudPlayerTarget.paused
        ? [this.qudPlayerTarget, this.qulPlayerTarget]
        : [this.qulPlayerTarget, this.qudPlayerTarget]
    if (!to.getAttribute("src")) return

    const at = from.currentTime
    from.pause()
    to.currentTime = at
    to.play()
  }

  // Jump both to the same point, e.g. to compare where an ayah starts.
  syncPosition() {
    const playing = [this.qulPlayerTarget, this.qudPlayerTarget].find((p) => !p.paused) || this.qulPlayerTarget
    const at = playing.currentTime
    ;[this.qulPlayerTarget, this.qudPlayerTarget].forEach((p) => {
      if (p !== playing && p.getAttribute("src")) p.currentTime = at
    })
  }

  pauseAll() {
    [this.qulPlayerTarget, this.qudPlayerTarget].forEach((p) => p.pause())
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}

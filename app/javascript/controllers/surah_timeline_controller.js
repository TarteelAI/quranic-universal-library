import { Controller } from "@hotwired/stimulus"

// Full-surah QA timeline for the segment-pipeline run page.
//
// Renders, over the decoded waveform, three stacked tracks — ayahs, forced-align
// words, and the raw STT stream — from the DB-free JSON the server builds out of
// the pipeline files. Words are coloured by the fix-step status (merged / repeat
// / missed), overlaps are outlined, and the slice of each ayah that contains an
// issue is underlined, so transcript problems and boundary overlaps are visible
// at a glance. A moving cursor tracks playback; the canvas is click-to-seek,
// zoomable, and horizontally scrollable.
//
// Only the visible time window is drawn each frame (the canvas stays viewport-
// width and sticky; a spacer provides the scroll extent), so long surahs at high
// zoom never hit the browser's max-canvas-size limit.
export default class extends Controller {
  static targets = ["scroll", "spacer", "canvas", "playButton", "zoomLabel", "time", "status"]
  static values = { url: String, audioUrl: String }

  static HEIGHT = 250
  static BANDS = {
    wave: [8, 78],
    ayah: [88, 118],
    word: [128, 176],
    stt: [186, 220],
    ruler: 236
  }
  static COLORS = {
    ok: "#9ca3af", merged: "#a855f7", repeat: "#3b82f6", missed: "#f59e0b",
    overlap: "#ef4444", wave: "#6b7280", stt: "#cbd5e1", cursor: "#dc2626",
    ayahLine: "rgba(30,41,59,0.15)"
  }

  connect() {
    this.timeline = null
    this.buffer = null
    this.loaded = false
    this.pps = 0
    this.playing = false
    this.rafId = null
    this.player = new Audio(this.audioUrlValue)
    this.player.preload = "none"
    this.onFrame = this.onFrame.bind(this)
    this.render = this.render.bind(this)
    this.onResize = this.onResize.bind(this)

    this.player.addEventListener("play", () => { this.playing = true; this.syncPlayButton(); this.startLoop() })
    this.player.addEventListener("pause", () => { this.playing = false; this.syncPlayButton(); this.stopLoop() })
    this.player.addEventListener("ended", () => { this.playing = false; this.syncPlayButton(); this.stopLoop() })
    window.addEventListener("resize", this.onResize)

    // Lazy-load only when the tab actually becomes visible (the panel is
    // display:none until selected, so the canvas has no width before that).
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) this.load()
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.stopLoop()
    this.player.pause()
    this.observer?.disconnect()
    window.removeEventListener("resize", this.onResize)
  }

  async load() {
    if (this.loaded) return
    this.loaded = true
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      this.timeline = await response.json()
    } catch (e) {
      this.statusTarget.textContent = "Could not load timeline data."
      return
    }
    if (!this.timeline.words || this.timeline.words.length === 0) {
      this.statusTarget.textContent = "No timeline yet — run forced alignment first."
      return
    }

    this.pps = this.fitPps()
    this.sizeCanvas()
    this.applyZoom()
    this.statusTarget.textContent =
      `${this.timeline.words.length} words · ${this.timeline.ayahs.length} ayahs · click to seek, scroll to pan, ± to zoom.`

    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      const bytes = await (await fetch(this.audioUrlValue)).arrayBuffer()
      this.buffer = await ctx.decodeAudioData(bytes)
    } catch (e) {
      this.buffer = null // render tracks without the waveform
    }
    this.render()
  }

  // --- geometry ------------------------------------------------------------

  viewportWidth() {
    return this.scrollTarget.clientWidth || 800
  }

  fitPps() {
    return Math.max(this.viewportWidth() / (this.timeline.duration || 1), 2)
  }

  sizeCanvas() {
    const canvas = this.canvasTarget
    canvas.width = this.viewportWidth()
    canvas.height = this.constructor.HEIGHT
  }

  applyZoom() {
    this.spacerTarget.style.width = `${Math.ceil(this.timeline.duration * this.pps)}px`
    this.spacerTarget.style.height = `${this.constructor.HEIGHT}px`
    this.zoomLabelTarget.textContent = `${Math.round(this.pps)} px/s`
  }

  timeToX(t) {
    return t * this.pps - this.scrollTarget.scrollLeft
  }

  xToTime(x) {
    return (x + this.scrollTarget.scrollLeft) / this.pps
  }

  // --- interaction ---------------------------------------------------------

  onResize() {
    if (!this.timeline) return
    this.sizeCanvas()
    this.render()
  }

  onScroll() {
    if (this.timeline) this.render()
  }

  zoomIn() { this.zoom(1.5) }
  zoomOut() { this.zoom(1 / 1.5) }

  zoom(factor) {
    if (!this.timeline) return
    const centerTime = this.xToTime(this.viewportWidth() / 2)
    const min = this.fitPps() / 2
    this.pps = Math.min(Math.max(this.pps * factor, min), 500)
    this.applyZoom()
    this.scrollTarget.scrollLeft = Math.max(centerTime * this.pps - this.viewportWidth() / 2, 0)
    this.render()
  }

  seek(event) {
    if (!this.timeline) return
    const rect = this.canvasTarget.getBoundingClientRect()
    this.player.currentTime = Math.max(this.xToTime(event.clientX - rect.left), 0)
    this.render()
  }

  togglePlay() {
    if (this.player.paused) this.player.play()
    else this.player.pause()
  }

  syncPlayButton() {
    this.playButtonTarget.textContent = this.player.paused ? "▶ Play" : "⏸ Pause"
  }

  startLoop() {
    this.stopLoop()
    this.rafId = requestAnimationFrame(this.onFrame)
  }

  stopLoop() {
    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = null
  }

  onFrame() {
    this.followCursor()
    this.render()
    if (this.playing) this.rafId = requestAnimationFrame(this.onFrame)
  }

  followCursor() {
    const x = this.timeToX(this.player.currentTime)
    const vw = this.viewportWidth()
    if (x < 0 || x > vw * 0.85) {
      this.scrollTarget.scrollLeft = Math.max(this.player.currentTime * this.pps - vw * 0.2, 0)
    }
  }

  // --- rendering -----------------------------------------------------------

  render() {
    if (!this.timeline) return
    const canvas = this.canvasTarget
    const vw = canvas.width
    const ctx = canvas.getContext("2d")
    const B = this.constructor.BANDS
    const C = this.constructor.COLORS
    ctx.clearRect(0, 0, vw, canvas.height)

    const t0 = this.xToTime(0)
    const t1 = this.xToTime(vw)
    const visible = (s, e) => e >= t0 && s <= t1

    this.drawWaveform(ctx, vw, t0, t1)

    // Ayah boundary lines through every track + ayah blocks.
    ctx.textBaseline = "middle"
    this.timeline.ayahs.forEach((ayah, i) => {
      if (ayah.start == null || !visible(ayah.start, ayah.end)) return
      const x = this.timeToX(ayah.start)
      const w = (ayah.end - ayah.start) * this.pps

      ctx.fillStyle = i % 2 === 0 ? "rgba(99,102,241,0.06)" : "rgba(99,102,241,0.12)"
      ctx.fillRect(x, B.ayah[0], w, B.ayah[1] - B.ayah[0])
      ctx.strokeStyle = C.ayahLine
      ctx.lineWidth = 1
      ctx.beginPath(); ctx.moveTo(x, B.wave[0]); ctx.lineTo(x, B.stt[1]); ctx.stroke()

      ctx.fillStyle = ayah.overlap ? C.overlap : "#4338ca"
      ctx.font = "11px sans-serif"
      const label = ayah.overlap ? `${ayah.number} ⚠` : `${ayah.number}`
      ctx.fillText(label, x + 4, (B.ayah[0] + B.ayah[1]) / 2)
    })

    // Word track — one block per forced-align word, coloured by fix-step status.
    this.timeline.words.forEach((word) => {
      if (word.start == null || !visible(word.start, word.end)) return
      const x = this.timeToX(word.start)
      const w = Math.max((word.end - word.start) * this.pps, 1)
      const color = C[word.status] || C.ok

      ctx.fillStyle = color
      ctx.globalAlpha = word.status === "missed" ? 0.45 : 0.85
      ctx.fillRect(x, B.word[0], w, B.word[1] - B.word[0])
      ctx.globalAlpha = 1

      if (word.overlap) {
        ctx.strokeStyle = C.overlap
        ctx.lineWidth = 2
        ctx.strokeRect(x + 1, B.word[0] + 1, w - 2, B.word[1] - B.word[0] - 2)
      }

      // Underline the slice of the ayah band that carries a fix-step issue.
      if (word.status && word.status !== "ok") {
        ctx.fillStyle = color
        ctx.fillRect(x, B.ayah[1] - 3, w, 3)
      }

      if (w > 26) {
        ctx.fillStyle = "#111827"
        ctx.font = "12px sans-serif"
        this.clippedText(ctx, word.text, x + 3, (B.word[0] + B.word[1]) / 2, w - 6)
      }
    })

    // STT reference track.
    ctx.fillStyle = C.stt
    this.timeline.stt_words.forEach((word) => {
      if (word.start == null || !visible(word.start, word.end)) return
      const x = this.timeToX(word.start)
      const w = Math.max((word.end - word.start) * this.pps, 1)
      ctx.fillRect(x, B.stt[0], w, B.stt[1] - B.stt[0])
    })

    this.drawTrackLabels(ctx)
    this.drawRuler(ctx, vw, t0, t1)
    this.drawCursor(ctx, canvas.height)
    this.updateClock()
  }

  drawWaveform(ctx, vw, t0, t1) {
    const B = this.constructor.BANDS
    const [top, bottom] = B.wave
    const mid = (top + bottom) / 2
    const half = (bottom - top) / 2

    ctx.fillStyle = "#f8fafc"
    ctx.fillRect(0, top, vw, bottom - top)
    if (!this.buffer) return

    const data = this.buffer.getChannelData(0)
    const rate = this.buffer.sampleRate
    ctx.strokeStyle = this.constructor.COLORS.wave
    ctx.lineWidth = 1
    ctx.beginPath()
    for (let x = 0; x < vw; x++) {
      const s = Math.floor(this.xToTime(x) * rate)
      const e = Math.floor(this.xToTime(x + 1) * rate)
      let min = 1.0, max = -1.0
      for (let i = s; i < e; i++) {
        const v = data[i] || 0
        if (v < min) min = v
        if (v > max) max = v
      }
      if (min > max) continue
      ctx.moveTo(x + 0.5, mid + min * half)
      ctx.lineTo(x + 0.5, mid + max * half)
    }
    ctx.stroke()
  }

  drawTrackLabels(ctx) {
    const B = this.constructor.BANDS
    ctx.font = "bold 10px sans-serif"
    ctx.textBaseline = "top"
    ;[["ayah", "AYAH"], ["word", "WORDS"], ["stt", "STT"]].forEach(([key, label]) => {
      // Draw on a translucent white pill so the label stays legible over the
      // waveform / coloured blocks behind it.
      const w = ctx.measureText(label).width
      ctx.fillStyle = "rgba(255,255,255,0.85)"
      ctx.fillRect(1, B[key][0] + 1, w + 6, 12)
      ctx.fillStyle = "#334155"
      ctx.fillText(label, 4, B[key][0] + 2)
    })
    ctx.textBaseline = "middle"
  }

  drawRuler(ctx, vw, t0, t1) {
    const y = this.constructor.BANDS.ruler
    const step = this.tickStep()
    ctx.strokeStyle = "#e2e8f0"
    ctx.fillStyle = "#94a3b8"
    ctx.font = "9px sans-serif"
    ctx.textBaseline = "top"
    for (let t = Math.ceil(t0 / step) * step; t <= t1; t += step) {
      const x = this.timeToX(t)
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + 6); ctx.stroke()
      ctx.fillText(this.clock(t), x + 2, y + 6)
    }
    ctx.textBaseline = "middle"
  }

  tickStep() {
    const target = 80 / this.pps // aim for a tick every ~80px
    for (const s of [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300]) {
      if (s >= target) return s
    }
    return 600
  }

  drawCursor(ctx, height) {
    const x = this.timeToX(this.player.currentTime)
    if (x < 0 || x > this.canvasTarget.width) return
    ctx.strokeStyle = this.constructor.COLORS.cursor
    ctx.lineWidth = 2
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height - 12); ctx.stroke()
  }

  clippedText(ctx, text, x, y, maxWidth) {
    ctx.save()
    ctx.beginPath()
    ctx.rect(x, y - 8, maxWidth, 16)
    ctx.clip()
    ctx.fillText(text, x, y)
    ctx.restore()
  }

  updateClock() {
    this.timeTarget.textContent = `${this.clock(this.player.currentTime)} / ${this.clock(this.timeline.duration)}`
  }

  clock(seconds) {
    const s = Math.max(Math.floor(seconds || 0), 0)
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
  }
}

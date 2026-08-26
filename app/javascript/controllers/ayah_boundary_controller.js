import { Controller } from "@hotwired/stimulus"

// Ayah boundary review/adjust tool on the segment-pipeline run page.
//
// The table lists each ayah read-only; clicking "Waveform" opens a sticky
// bottom popup that is the per-ayah editor: it shows the full ayah text, the
// waveform region (with a few seconds of padding so the silence before/after is
// visible and the ayah span shaded), a moving playback cursor, click-to-seek, a
// play/pause toggle, prev/next navigation, editable start/end fields, and Save
// (a normal POST back to alignment.json).
export default class extends Controller {
  static targets = [
    "player", "popup", "canvas", "title", "text", "waveLabel", "form",
    "numberField", "startInput", "endInput",
    "playButton", "popupDuration", "prevButton", "nextButton"
  ]
  static values = { audioUrl: String, ayahs: Array }

  // Seconds of audio drawn on either side of the ayah, so the surrounding
  // silences are visible.
  static PAD = 2

  connect() {
    this.stopAt = null
    this.buffer = null
    this.activeIndex = null
    this.region = null      // { from, to, width } for the current drawing
    this.baseImage = null   // cached waveform pixels; cursor is overlaid on top
    this.rafId = null
    this.onTimeUpdate = this.onTimeUpdate.bind(this)
    this.onPlay = this.onPlay.bind(this)
    this.onStop = this.onStop.bind(this)
    this.player().addEventListener("timeupdate", this.onTimeUpdate)
    this.player().addEventListener("play", this.onPlay)
    this.player().addEventListener("pause", this.onStop)
    this.player().addEventListener("ended", this.onStop)
  }

  disconnect() {
    this.stopCursorLoop()
    this.player().removeEventListener("timeupdate", this.onTimeUpdate)
    this.player().removeEventListener("play", this.onPlay)
    this.player().removeEventListener("pause", this.onStop)
    this.player().removeEventListener("ended", this.onStop)
  }

  // --- opening / navigation ------------------------------------------------

  async openIndex(event) {
    this.activeIndex = parseInt(event.currentTarget.dataset.index, 10)
    this.popupTarget.classList.remove("hidden")
    this.populate()
    try {
      await this.ensureBuffer()
      this.draw()
    } catch (e) {
      this.waveLabelTarget.textContent = "Could not decode audio for the waveform. "
    }
  }

  prev() {
    if (this.activeIndex > 0) this.go(this.activeIndex - 1)
  }

  next() {
    if (this.activeIndex < this.ayahsValue.length - 1) this.go(this.activeIndex + 1)
  }

  go(index) {
    this.pause()
    this.activeIndex = index
    this.populate()
    if (this.buffer) this.draw()
  }

  close() {
    this.pause()
    this.popupTarget.classList.add("hidden")
  }

  // --- playback ------------------------------------------------------------

  togglePlay() {
    if (this.player().paused) this.playClip()
    else this.pause()
  }

  // Play from the cursor to the end of the ayah. If the cursor sits past the
  // ayah (or before the drawn region), restart from the ayah start — otherwise
  // resume from wherever it was seeked to, so you can replay a spot.
  playClip() {
    const { start, end } = this.currentBounds()
    if (Number.isNaN(start) || Number.isNaN(end)) return

    this.stopAt = end
    const t = this.player().currentTime
    const from = this.region ? this.region.from : start
    if (Number.isNaN(t) || t < from || t >= end) this.player().currentTime = start
    this.player().play()
  }

  pause() {
    this.stopAt = null
    if (!this.player().paused) this.player().pause()
  }

  // Click anywhere on the waveform to move the cursor there and replay from it.
  seek(event) {
    if (!this.region) return
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) * (this.canvasTarget.width / rect.width)
    const { from, to, width } = this.region
    const time = from + (x / width) * (to - from)
    this.player().currentTime = Math.min(Math.max(time, 0), this.buffer.duration)
    this.paintCursor()
  }

  onTimeUpdate() {
    if (this.stopAt !== null && this.player().currentTime >= this.stopAt) {
      this.stopAt = null
      this.player().pause()
    }
  }

  onPlay() {
    this.syncPlayButton()
    this.startCursorLoop()
  }

  onStop() {
    this.syncPlayButton()
    this.stopCursorLoop()
  }

  syncPlayButton() {
    this.playButtonTarget.textContent = this.player().paused ? "▶ Play" : "⏸ Pause"
  }

  startCursorLoop() {
    const tick = () => {
      this.paintCursor()
      this.rafId = requestAnimationFrame(tick)
    }
    this.stopCursorLoop()
    this.rafId = requestAnimationFrame(tick)
  }

  stopCursorLoop() {
    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = null
  }

  // --- editing -------------------------------------------------------------

  onInput() {
    this.updateDuration()
    if (this.buffer) this.draw()
  }

  // --- rendering -----------------------------------------------------------

  populate() {
    const ayah = this.ayahsValue[this.activeIndex]
    if (!ayah) return

    this.titleTarget.textContent = `Ayah ${ayah.number}`
    this.textTarget.textContent = ayah.text || ""
    this.numberFieldTarget.value = ayah.number
    this.startInputTarget.value = ayah.start == null ? "" : Number(ayah.start).toFixed(3)
    this.endInputTarget.value = ayah.end == null ? "" : Number(ayah.end).toFixed(3)

    this.updateDuration()
    this.prevButtonTarget.disabled = this.activeIndex <= 0
    this.nextButtonTarget.disabled = this.activeIndex >= this.ayahsValue.length - 1
    this.syncPlayButton()
  }

  updateDuration() {
    const { start, end } = this.currentBounds()
    this.popupDurationTarget.textContent =
      Number.isNaN(start) || Number.isNaN(end) ? "" : `${(end - start).toFixed(3)}s`
  }

  currentBounds() {
    return {
      start: parseFloat(this.startInputTarget.value),
      end: parseFloat(this.endInputTarget.value)
    }
  }

  async ensureBuffer() {
    if (this.buffer) return this.buffer
    const context = new (window.AudioContext || window.webkitAudioContext)()
    const response = await fetch(this.audioUrlValue)
    const bytes = await response.arrayBuffer()
    this.buffer = await context.decodeAudioData(bytes)
    return this.buffer
  }

  draw() {
    const { start, end } = this.currentBounds()
    if (!this.buffer || Number.isNaN(start) || Number.isNaN(end)) return

    const duration = this.buffer.duration
    const from = Math.max(0, start - this.constructor.PAD)
    const to = Math.min(duration, end + this.constructor.PAD)
    if (to <= from) return

    const canvas = this.canvasTarget
    const width = (canvas.width = canvas.clientWidth || 600)
    const height = canvas.height
    const ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, width, height)

    const timeToX = (t) => ((t - from) / (to - from)) * width

    ctx.fillStyle = "rgba(79, 70, 229, 0.12)"
    ctx.fillRect(timeToX(start), 0, timeToX(end) - timeToX(start), height)

    this.drawWaveform(ctx, width, height, from, to)

    ctx.strokeStyle = "rgba(16, 185, 129, 0.9)"
    ctx.lineWidth = 2
    for (const t of [start, end]) {
      const x = timeToX(t)
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, height)
      ctx.stroke()
    }

    this.waveLabelTarget.textContent = `Showing ${from.toFixed(2)}s–${to.toFixed(2)}s (±${this.constructor.PAD}s). Click to seek. `

    // Cache the static drawing; the moving cursor is painted on top of it.
    this.region = { from, to, width }
    this.baseImage = ctx.getImageData(0, 0, width, height)
    this.paintCursor()
  }

  paintCursor() {
    if (!this.region || !this.baseImage) return

    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    ctx.putImageData(this.baseImage, 0, 0)

    const { from, to, width } = this.region
    const time = this.player().currentTime
    if (time < from || time > to) return

    const x = ((time - from) / (to - from)) * width
    ctx.strokeStyle = "rgba(220, 38, 38, 0.95)"
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(x, 0)
    ctx.lineTo(x, canvas.height)
    ctx.stroke()
  }

  drawWaveform(ctx, width, height, from, to) {
    const data = this.buffer.getChannelData(0)
    const rate = this.buffer.sampleRate
    const startSample = Math.floor(from * rate)
    const endSample = Math.min(data.length, Math.floor(to * rate))
    const samplesPerPixel = Math.max(1, Math.floor((endSample - startSample) / width))
    const mid = height / 2

    ctx.strokeStyle = "rgba(55, 65, 81, 0.8)"
    ctx.lineWidth = 1
    ctx.beginPath()
    for (let x = 0; x < width; x++) {
      const sliceStart = startSample + x * samplesPerPixel
      let min = 1.0
      let max = -1.0
      for (let i = 0; i < samplesPerPixel; i++) {
        const value = data[sliceStart + i] || 0
        if (value < min) min = value
        if (value > max) max = value
      }
      ctx.moveTo(x + 0.5, mid + min * mid)
      ctx.lineTo(x + 0.5, mid + max * mid)
    }
    ctx.stroke()
  }

  player() {
    return this.playerTarget
  }
}

import { Controller } from "@hotwired/stimulus"

// Plays one ayah of the surah audio and stops at its end. The play button
// carries the range (data-from / data-to, in ms) and, optionally, the word
// timings (data-words: [[position, from, to], ...]); while it plays, the
// [data-position] elements inside the button's card light up as their word is
// recited. Used on the Fix step, where the card is the ayah's [data-ayah-key].
export default class extends Controller {
  static targets = ["player", "status", "stop"]

  connect() {
    this.stopAt = null
    this.words = []
    this.card = null
    this.lit = []
  }

  disconnect() {
    this.stop()
  }

  play(event) {
    const button = event.currentTarget
    const from = Number(button.dataset.from)
    const to = Number(button.dataset.to)
    if (!Number.isFinite(from) || !Number.isFinite(to) || !this.hasPlayerTarget) return

    this.clear()
    this.card = button.closest("[data-ayah-key]")
    this.words = JSON.parse(button.dataset.words || "[]")
    this.stopAt = to
    this.playerTarget.currentTime = from / 1000
    // Refused (e.g. autoplay blocked): undo the "Playing…" state rather than leave it up.
    this.playerTarget.play().catch(() => this.stop())
    if (this.hasStatusTarget) this.statusTarget.textContent = `Playing ${this.card?.dataset.ayahKey || ""}`
    if (this.hasStopTarget) this.stopTarget.hidden = false
    this.pump()
  }

  stop() {
    if (this.hasPlayerTarget) this.playerTarget.pause()
    if (this.raf) cancelAnimationFrame(this.raf)
    this.stopAt = null
    this.clear()
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
    if (this.hasStopTarget) this.stopTarget.hidden = true
  }

  // Off the frame clock, not timeupdate (~4/s), so the stop is not late and the
  // word highlight keeps up with short words.
  pump() {
    const ms = this.playerTarget.currentTime * 1000
    if (this.stopAt != null && ms >= this.stopAt) return this.stop()
    if (this.playerTarget.paused) return // paused by hand: keep the ayah, stop painting

    this.paint(ms)
    this.raf = requestAnimationFrame(() => this.pump())
  }

  paint(ms) {
    if (!this.card) return
    const active = this.words.find(([, from, to]) => ms >= from && ms < to)
    const position = active ? String(active[0]) : null
    if (position === this.litPosition) return

    this.clear()
    this.litPosition = position
    if (!position) return
    this.lit = [...this.card.querySelectorAll(`[data-position="${position}"]`)]
    this.lit.forEach((el) => el.classList.add("ring-2", "ring-indigo-400"))
  }

  clear() {
    this.lit.forEach((el) => el.classList.remove("ring-2", "ring-indigo-400"))
    this.lit = []
    this.litPosition = null
  }
}

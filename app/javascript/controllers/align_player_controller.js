import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player", "alignedWord", "sttWord", "ayahSelect", "ayahInput"]
  static values = { audioUrl: String, ayahs: Array }

  connect() {
    this.stopAt = null
    this.lastAligned = null
    this.lastStt = null
    this.onTimeUpdate = this.onTimeUpdate.bind(this)
    if (this.hasPlayerTarget) {
      this.playerTarget.addEventListener("timeupdate", this.onTimeUpdate)
    }
  }

  disconnect() {
    if (this.hasPlayerTarget) {
      this.playerTarget.removeEventListener("timeupdate", this.onTimeUpdate)
    }
  }

  play(event) {
    const start = parseFloat(event.currentTarget.dataset.start)
    const end = parseFloat(event.currentTarget.dataset.end)
    if (Number.isNaN(start) || !this.hasPlayerTarget) return

    this.stopAt = Number.isNaN(end) ? null : end
    this.playerTarget.currentTime = start
    this.playerTarget.play()
  }

  jumpToSelected(event) {
    this.jumpTo(event.currentTarget.value)
    if (this.hasAyahInputTarget) this.ayahInputTarget.value = ""
  }

  jumpToInput() {
    if (!this.hasAyahInputTarget) return
    const value = this.ayahInputTarget.value.trim()
    if (this.jumpTo(value) && this.hasAyahSelectTarget) {
      this.ayahSelectTarget.value = ""
    }
  }

  jumpTo(value) {
    if (!value || !this.hasPlayerTarget) return false

    const points = this.ayahsValue || []
    const point =
      points.find((p) => p.key === value) ||
      points.find((p) => String(p.number) === String(value))
    if (!point || point.start == null) return false

    this.stopAt = null
    this.playerTarget.currentTime = point.start
    this.playerTarget.play()
    return true
  }

  onTimeUpdate() {
    const time = this.playerTarget.currentTime

    if (this.stopAt !== null && time >= this.stopAt) {
      this.playerTarget.pause()
      this.stopAt = null
    }

    this.lastAligned = this.highlight(this.alignedWordTargets, time, this.lastAligned)
    this.lastStt = this.highlight(this.sttWordTargets, time, this.lastStt)
  }

  highlight(rows, time, previous) {
    const active = rows.find((row) => {
      const start = parseFloat(row.dataset.start)
      const end = parseFloat(row.dataset.end)
      return !Number.isNaN(start) && !Number.isNaN(end) && time >= start && time < end
    })

    if (active === previous) return previous

    if (previous) previous.classList.remove("bg-yellow-200")
    if (active) {
      active.classList.add("bg-yellow-200")
      active.scrollIntoView({ block: "nearest", inline: "nearest" })
    }
    return active || null
  }
}

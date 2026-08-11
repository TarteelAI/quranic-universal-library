import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { statusUrl: String, interval: Number }

  connect() {
    this.poll = this.poll.bind(this)
    this.timer = setInterval(this.poll, this.intervalValue || 7000)
    this.poll()
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const data = await response.json()
      ;(data.runs || []).forEach((run) => this.updateRow(run))
    } catch (error) {
      return
    }
  }

  updateRow(run) {
    const row = this.element.querySelector(`[data-run-chapter="${run.chapter_id}"]`)
    if (!row) return

    this.setField(row, "step", run.current_step || "—")
    this.setField(row, "last_log", run.last_log || "")

    const badge = row.querySelector('[data-field="status"]')
    if (badge) {
      badge.textContent = run.status || "—"
      badge.className = this.badgeClass(run.status)
    }

    const error = row.querySelector('[data-field="error"]')
    if (error) {
      if (run.error) {
        error.textContent = run.error
        error.classList.remove("hidden")
      } else {
        error.textContent = ""
        error.classList.add("hidden")
      }
    }

    if (run.coverage !== null && run.coverage !== undefined) {
      this.setField(row, "coverage", `${run.coverage}%`)
    }
  }

  setField(row, field, value) {
    const element = row.querySelector(`[data-field="${field}"]`)
    if (element) element.textContent = value
  }

  badgeClass(status) {
    const base = "inline-block px-2 py-0.5 rounded text-xs font-medium "
    const map = {
      running: "bg-amber-100 text-amber-700",
      completed: "bg-emerald-100 text-emerald-700",
      failed: "bg-red-100 text-red-700",
      pending: "bg-gray-100 text-gray-600"
    }
    return base + (map[status] || "bg-gray-50 text-gray-400")
  }
}

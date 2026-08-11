import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "panel"]
  static values = { statusUrl: String, chapterId: Number, default: String, interval: Number }

  connect() {
    this.show(this.defaultValue || this.firstStepKey())
    if (this.hasStatusUrlValue) {
      this.poll = this.poll.bind(this)
      this.timer = setInterval(this.poll, this.intervalValue || 7000)
      this.poll()
    }
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  select(event) {
    this.show(event.currentTarget.dataset.stepKey)
  }

  show(key) {
    this.panelTargets.forEach((panel) => panel.classList.toggle("hidden", panel.dataset.stepKey !== key))
    this.stepTargets.forEach((step) => {
      const active = step.dataset.stepKey === key
      step.classList.toggle("ring-2", active)
      step.classList.toggle("ring-indigo-400", active)
    })
  }

  firstStepKey() {
    return this.stepTargets[0] ? this.stepTargets[0].dataset.stepKey : null
  }

  async poll() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const data = await response.json()
      const run = (data.runs || []).find((r) => r.chapter_id === this.chapterIdValue)
      if (run) this.applyRun(run)
      if (!data.any_active && this.timer) {
        clearInterval(this.timer)
        this.timer = null
      }
    } catch (error) {
      return
    }
  }

  applyRun(run) {
    this.setField("step", run.current_step || "—")
    this.setField("last_log", run.last_log || "")

    const badge = this.element.querySelector('[data-field="status"]')
    if (badge) {
      badge.textContent = run.status || "—"
      badge.className = this.statusClass(run.status)
    }

    const error = this.element.querySelector('[data-field="error"]')
    if (error) {
      if (run.error) {
        error.textContent = run.error
        error.classList.remove("hidden")
      } else {
        error.textContent = ""
        error.classList.add("hidden")
      }
    }

    this.recolorTimeline(run)
  }

  recolorTimeline(run) {
    const order = this.stepTargets.map((step) => step.dataset.stepKey)
    const currentIndex = order.indexOf(run.current_step)
    const completed = run.status === "completed" || run.current_step === "done"

    this.stepTargets.forEach((step, index) => {
      let state
      if (completed) state = "done"
      else if (currentIndex === -1) state = "pending"
      else if (index < currentIndex) state = "done"
      else if (index === currentIndex) state = run.status === "failed" ? "failed" : "active"
      else state = "pending"
      this.applyDotState(step, state)
    })
  }

  applyDotState(step, state) {
    const dot = step.querySelector("[data-dot]")
    if (dot) {
      const base = "w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold "
      dot.className = base + this.dotClass(state)
    }
    const label = step.querySelector("[data-state-label]")
    if (label) label.textContent = state
  }

  setField(field, value) {
    const element = this.element.querySelector(`[data-field="${field}"]`)
    if (element) element.textContent = value
  }

  dotClass(state) {
    const map = {
      done: "bg-emerald-500 text-white",
      active: "bg-amber-500 text-white animate-pulse",
      failed: "bg-red-500 text-white"
    }
    return map[state] || "bg-gray-200 text-gray-500"
  }

  statusClass(status) {
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

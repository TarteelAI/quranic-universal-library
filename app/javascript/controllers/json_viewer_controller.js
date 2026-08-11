import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tree", "raw"]

  connect() {
    if (!this.hasTreeTarget || !this.hasRawTarget) return
    try {
      const data = JSON.parse(this.rawTarget.textContent)
      this.treeTarget.appendChild(this.buildNode(null, data, true))
      this.showTree()
    } catch (error) {
      this.showRaw()
    }
  }

  showTree() {
    if (this.hasTreeTarget) this.treeTarget.classList.remove("hidden")
    if (this.hasRawTarget) this.rawTarget.classList.add("hidden")
  }

  showRaw() {
    if (this.hasTreeTarget) this.treeTarget.classList.add("hidden")
    if (this.hasRawTarget) this.rawTarget.classList.remove("hidden")
  }

  buildNode(key, value, open = false) {
    const wrapper = document.createElement("div")
    wrapper.className = "leading-6"

    const isObject = value !== null && typeof value === "object"

    if (!isObject) {
      wrapper.appendChild(this.keyLabel(key))
      const span = document.createElement("span")
      span.textContent = this.formatPrimitive(value)
      span.className = this.primitiveClass(value)
      wrapper.appendChild(span)
      return wrapper
    }

    const entries = Array.isArray(value)
      ? value.map((item, index) => [index, item])
      : Object.entries(value)

    const details = document.createElement("details")
    if (open) details.open = true

    const summary = document.createElement("summary")
    summary.className = "cursor-pointer select-none"
    summary.appendChild(this.keyLabel(key))
    const meta = document.createElement("span")
    meta.className = "text-gray-400"
    meta.textContent = Array.isArray(value) ? `Array(${entries.length})` : `Object(${entries.length})`
    summary.appendChild(meta)
    details.appendChild(summary)

    const children = document.createElement("div")
    children.className = "pl-4 border-l border-gray-200 ml-1"
    entries.forEach(([childKey, childValue]) => {
      children.appendChild(this.buildNode(childKey, childValue))
    })
    details.appendChild(children)
    wrapper.appendChild(details)
    return wrapper
  }

  keyLabel(key) {
    const label = document.createElement("span")
    if (key === null) {
      label.textContent = ""
    } else {
      label.textContent = `${key}: `
      label.className = "text-indigo-700 font-medium"
    }
    return label
  }

  formatPrimitive(value) {
    if (value === null) return "null"
    if (typeof value === "string") return `"${value}"`
    return String(value)
  }

  primitiveClass(value) {
    if (typeof value === "number") return "text-emerald-700"
    if (typeof value === "boolean") return "text-purple-700"
    if (value === null) return "text-gray-400"
    return "text-gray-800"
  }
}

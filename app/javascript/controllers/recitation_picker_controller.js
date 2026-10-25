import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results"]
  static values = { searchUrl: String }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.run(), 250)
  }

  async run() {
    const query = this.queryTarget.value.trim()
    if (query.length < 2) return

    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const { recitations } = await response.json()
      this.render(recitations || [])
    } catch (error) {
      // A failed search leaves the previous results in place; the operator can retry.
    }
  }

  render(recitations) {
    this.resultsTarget.replaceChildren()

    if (!recitations.length) {
      const empty = document.createElement("p")
      empty.className = "px-2 py-3 text-xs text-gray-400"
      empty.textContent = "No reciters match that."
      this.resultsTarget.appendChild(empty)
      return
    }

    recitations.forEach((recitation) => {
      const label = document.createElement("label")
      label.className = "flex items-start gap-2 px-2 py-1.5 hover:bg-gray-50 cursor-pointer text-xs"

      const radio = document.createElement("input")
      radio.type = "radio"
      radio.name = "audio_recitation_id"
      radio.value = recitation.id
      radio.className = "mt-0.5"
      label.appendChild(radio)

      const text = document.createElement("span")
      const title = document.createElement("span")
      title.className = "font-medium text-gray-800"
      title.textContent = `#${recitation.id} ${recitation.name}`
      text.appendChild(title)

      // Spell out the two things that make an attach a mistake: it is already
      // claimed by another delivery, or its segments are locked.
      if (recitation.qua_key) {
        const mapped = document.createElement("span")
        mapped.className = "text-amber-600"
        mapped.textContent = ` · already mapped to ${recitation.qua_key}`
        text.appendChild(mapped)
      }
      if (recitation.locked) {
        const locked = document.createElement("span")
        locked.className = "text-red-600"
        locked.textContent = " · 🔒 locked"
        text.appendChild(locked)
      }

      const meta = document.createElement("span")
      meta.className = "block text-gray-500"
      meta.textContent = `${recitation.segments_count || 0} segments · ${recitation.files_count || 0} files`
      text.appendChild(meta)

      label.appendChild(text)
      this.resultsTarget.appendChild(label)
    })
  }
}

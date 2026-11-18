import { Controller } from "@hotwired/stimulus"

// The ayah picker above the segment pipeline's steps. Picking an ayah puts it
// in the URL (?ayah=2:76, so the address can be shared) and:
//   - hides every server-rendered [data-ayah-filter-key] element of another
//     ayah (the Fix step's cards, the Ayah boundary rows);
//   - tells the script-driven steps (Compare, Align, Surah timeline) through a
//     window "segment-pipeline:ayah" event, { detail: { key } }, and each one
//     reads the same ?ayah= parameter to follow it.
// An empty value ("All ayahs") clears the filter.
export const AYAH_EVENT = "segment-pipeline:ayah"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.apply(new URLSearchParams(window.location.search).get("ayah") || "")
  }

  change() {
    const key = this.selectTarget.value || ""
    const url = new URL(window.location.href)
    if (key) url.searchParams.set("ayah", key)
    else url.searchParams.delete("ayah")
    window.history.replaceState(window.history.state, "", url)

    this.apply(key)
    window.dispatchEvent(new CustomEvent(AYAH_EVENT, { detail: { key } }))
  }

  apply(key) {
    document.querySelectorAll("[data-ayah-filter-key]").forEach((el) => {
      el.style.display = !key || el.dataset.ayahFilterKey === key ? "" : "none"
    })
  }
}

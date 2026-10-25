import { Controller } from "@hotwired/stimulus"

// Tabs on the resource detail page. Each tab is a real URL
// (/resources/:type/:id/docs), so the address bar can be copied and a fresh
// load renders the same tab on the server.
export default class extends Controller {
  static targets = ["tab", "pane"]

  select(event) {
    // Let ctrl/cmd/middle-click open the tab URL in a new browser tab.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button > 0) return
    event.preventDefault()

    const link = event.currentTarget
    const key = link.dataset.tab

    const current = this.paneTargets.find((pane) => !pane.hidden)
    const next = this.paneFor(key)
    this.holdHeightUntilLoaded(next, current?.offsetHeight)

    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab === link))
    this.paneTargets.forEach((pane) => { pane.hidden = pane !== next })

    // Keep query params (e.g. ?ayah=) so switching back restores the preview.
    const url = new URL(link.href)
    url.search = window.location.search
    this.replaceUrl(url)

    this.dispatch("shown", { detail: { tab: key } })
  }

  // Start loading a lazy tab on hover/focus, so it's usually ready by the click.
  prefetch(event) {
    const frame = this.frameIn(this.paneFor(event.currentTarget.dataset.tab))
    if (frame && frame.loading === "lazy") frame.loading = "eager"
  }

  // A lazy tab shows a one-line placeholder until its content arrives. Keep it
  // as tall as the tab we're leaving so the page doesn't shrink and jump.
  holdHeightUntilLoaded(pane, height) {
    const frame = this.frameIn(pane)
    if (!frame || frame.hasAttribute("complete") || !height) return

    pane.style.minHeight = `${height}px`
    frame.addEventListener("turbo:frame-load", () => { pane.style.minHeight = "" }, { once: true })
    frame.loading = "eager"
  }

  paneFor(key) {
    return this.paneTargets.find((pane) => pane.dataset.tab === key)
  }

  frameIn(pane) {
    return pane?.querySelector("turbo-frame[src]")
  }

  // Go through Turbo so its own idea of the current location stays in sync.
  replaceUrl(url) {
    const turboHistory = window.Turbo?.navigator?.history
    if (turboHistory) {
      turboHistory.replace(url)
    } else {
      window.history.replaceState(window.history.state, "", url)
    }
  }
}

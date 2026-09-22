import { Controller } from "@hotwired/stimulus"

// Shows the current and draft tafsir text for one ayah side by side.
// It builds its own overlay stacked above the ajax-modal it is opened from, so
// the comparison table underneath stays untouched.
export default class extends Controller {
  static values = { url: String }

  disconnect() {
    this.close();
  }

  // Delegated from the table body: one listener rather than one per row.
  open(event) {
    const trigger = event.target.closest(".status_tag");
    if (!trigger) return;

    event.preventDefault();
    event.stopPropagation();

    const verseKey = trigger.closest("tr").querySelector("td strong").textContent.trim();
    this.close();
    this.build(verseKey);

    fetch(`${this.urlValue}?verse_key=${encodeURIComponent(verseKey)}`, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
      .then((response) => {
        if (!response.ok) throw new Error(response.statusText);
        return response.text();
      })
      .then((html) => {
        if (this.bodyElement) this.bodyElement.innerHTML = html;
      })
      .catch(() => {
        if (this.bodyElement) {
          this.bodyElement.innerHTML = `<div class="p-4 text-red-600">Could not load text for ${verseKey}.</div>`;
        }
      });
  }

  build(verseKey) {
    const overlay = document.createElement("div");
    // Above the ajax-modal, which sits at z-[9999].
    overlay.className = "fixed inset-0 z-[10050] overflow-y-auto bg-black bg-opacity-50";
    overlay.innerHTML = `
      <div class="flex min-h-full items-start justify-center p-4">
        <div class="relative w-full max-w-6xl bg-white rounded-lg shadow-xl" data-popup-content>
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200">
            <h5 class="text-lg font-semibold m-0">${verseKey}</h5>
            <button type="button" class="btn btn-sm btn-secondary" data-popup-close>Close</button>
          </div>
          <div class="max-h-[80vh] overflow-y-auto" data-popup-body>
            <div class="p-4 text-gray-500">Loading…</div>
          </div>
        </div>
      </div>
    `;

    overlay.addEventListener("click", (e) => {
      if (e.target.closest("[data-popup-close]") || !e.target.closest("[data-popup-content]")) {
        this.close();
      }
    });

    this.escapeHandler = (e) => {
      if (e.key === "Escape") {
        // Close this popup only; the comparison modal handles Escape itself.
        e.stopImmediatePropagation();
        this.close();
      }
    };
    document.addEventListener("keydown", this.escapeHandler, true);

    document.body.appendChild(overlay);
    this.overlayElement = overlay;
    this.bodyElement = overlay.querySelector("[data-popup-body]");
  }

  close() {
    if (this.overlayElement) {
      this.overlayElement.remove();
      this.overlayElement = null;
      this.bodyElement = null;
    }
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler, true);
      this.escapeHandler = null;
    }
  }
}

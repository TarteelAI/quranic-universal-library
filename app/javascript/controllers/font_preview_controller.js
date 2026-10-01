import { Controller } from "@hotwired/stimulus"
import * as fontkit from "fontkit"
import { Buffer } from "buffer"

window.Buffer = Buffer

// Glyph names that every font carries but nobody wants to browse.
const RESERVED_GLYPH_NAMES = [".notdef", ".null", "nonmarkingreturn", "NULL", "CR"]

export default class extends Controller {
  static targets = [
    "sampleText", "sampleTextInput",
    "fontSizeSlider", "fontSizeValue",
    "lineHeightSlider", "lineHeightValue",
    "glyphsContainer", "glyphSearch", "glyphZoom", "glyphCount",
    "unmappedToggle", "emptyToggle",
    "ligaturesTable", "ligatureSearch", "ligatureSizeSlider", "ligatureSizeValue",
    "ligatureCount", "ligaturePreview"
  ]

  static values = {
    fontUrl: String,
    fontFormat: String,
    fontFace: String,
    sampleText: String
  }

  connect() {
    this.font = null
    this.glyphs = []
    this.loadState = "idle"
    this.searchTimer = null
    this.glyphsRendered = false

    this.setGlyphCellSize(this.hasGlyphZoomTarget ? Number(this.glyphZoomTarget.value) : 120)
    this.updateLigatureCount()
    this.loadFont()
  }

  disconnect() {
    clearTimeout(this.searchTimer)
    this.closeGlyphModal()
  }

  // ---------------------------------------------------------------- font load

  async loadFont() {
    if (this.loadState !== "idle") return this.fontPromise
    this.loadState = "loading"

    this.fontPromise = (async () => {
      const response = await fetch(this.fontUrlValue)
      if (!response.ok) throw new Error(`Could not download the font (HTTP ${response.status})`)

      this.font = fontkit.create(Buffer.from(await response.arrayBuffer()))
      this.glyphs = this.collectGlyphs(this.font)
      this.loadState = "loaded"
    })()

    this.fontPromise.catch((error) => {
      console.error("font-preview: failed to load font", error)
      this.loadState = "error"
      this.loadError = error
    })

    return this.fontPromise
  }

  // Walks every glyph in the font, not only the ones reachable from cmap, so
  // ligature-only glyphs (Surah name fonts, QCF word glyphs) show up too.
  collectGlyphs(font) {
    const codePointsByGlyph = new Map()
    font.characterSet.forEach((codePoint) => {
      const glyph = font.glyphForCodePoint(codePoint)
      if (!glyph) return
      if (!codePointsByGlyph.has(glyph.id)) codePointsByGlyph.set(glyph.id, [])
      codePointsByGlyph.get(glyph.id).push(codePoint)
    })

    const glyphs = []
    for (let id = 0; id < font.numGlyphs; id++) {
      let glyph
      try {
        glyph = font.getGlyph(id)
      } catch (error) {
        continue
      }
      if (!glyph) continue

      const name = glyph.name || ""
      if (RESERVED_GLYPH_NAMES.includes(name)) continue

      const codePoints = (codePointsByGlyph.get(id) || []).sort((a, b) => a - b)
      // QCF page fonts map each word glyph from both an ASCII byte and its real
      // Arabic codepoint. The Arabic one is what a reader is looking for.
      const primary = codePoints.find((cp) => cp >= 0x0600) ?? codePoints[0]
      const char = primary === undefined ? "" : String.fromCodePoint(primary)
      const hex = primary === undefined ? null : this.toHex(primary)

      glyphs.push({
        id,
        glyph,
        empty: !this.glyphBox(glyph),
        name,
        char,
        hex,
        codePoints,
        // Several codepoints often share one glyph, so every one of them has to
        // be searchable, not just the first.
        primary,
        haystack: [name, `#${id}`, char]
          .concat(codePoints.flatMap((cp) => [`u+${this.toHex(cp)}`, this.toHex(cp)]))
          .join(" ")
          .toLowerCase()
      })
    }

    // Codepoint order reads like a character map; unmapped glyphs go last.
    return glyphs.sort((a, b) => {
      const aKey = a.primary ?? Infinity
      const bKey = b.primary ?? Infinity
      return aKey - bKey || a.id - b.id
    })
  }

  toHex(codePoint) {
    return codePoint.toString(16).toUpperCase().padStart(4, "0")
  }

  // ------------------------------------------------------------ live preview

  updateSampleText(event) {
    if (this.hasSampleTextTarget) this.sampleTextTarget.textContent = event.target.value
  }

  updateFontSize(event) {
    const size = `${event.target.value}px`
    if (this.hasSampleTextTarget) this.sampleTextTarget.style.fontSize = size
    if (this.hasFontSizeValueTarget) this.fontSizeValueTarget.textContent = size
  }

  updateLineHeight(event) {
    const lineHeight = (Number(event.target.value) / 10).toFixed(1)
    if (this.hasSampleTextTarget) this.sampleTextTarget.style.lineHeight = lineHeight
    if (this.hasLineHeightValueTarget) this.lineHeightValueTarget.textContent = lineHeight
  }

  updateDirection(event) {
    const dir = event.target.value
    if (this.hasSampleTextTarget) this.sampleTextTarget.setAttribute("dir", dir)
    if (this.hasSampleTextInputTarget) this.sampleTextInputTarget.setAttribute("dir", dir)
  }

  resetPreview() {
    if (this.hasSampleTextInputTarget) this.sampleTextInputTarget.value = this.sampleTextValue
    if (this.hasSampleTextTarget) {
      this.sampleTextTarget.textContent = this.sampleTextValue
      this.sampleTextTarget.style.fontSize = "40px"
      this.sampleTextTarget.style.lineHeight = "1.7"
      this.sampleTextTarget.setAttribute("dir", "rtl")
    }
    if (this.hasFontSizeSliderTarget) this.fontSizeSliderTarget.value = 40
    if (this.hasFontSizeValueTarget) this.fontSizeValueTarget.textContent = "40px"
    if (this.hasLineHeightSliderTarget) this.lineHeightSliderTarget.value = 17
    if (this.hasLineHeightValueTarget) this.lineHeightValueTarget.textContent = "1.7"
  }

  // ---------------------------------------------------------------- ligatures

  async showLigatures() {
    this.updateLigatureCount()
    if (this.ligaturesDrawn) return

    try {
      await this.loadFont()
    } catch (error) {
      // Leave the CSS-rendered fallback text in place.
      return
    }

    this.ligaturesDrawn = true
    this.renderLigaturePreviews()
  }

  // Decorative ligature glyphs draw far outside the em box, so letting the
  // browser lay them out overflows the row. Fit each one to its own outline
  // on a canvas instead.
  renderLigaturePreviews() {
    const size = this.hasLigatureSizeSliderTarget ? Number(this.ligatureSizeSliderTarget.value) : 40
    this.ligaturePreviewTargets.forEach((host) => this.drawLigature(host, size))
  }

  drawLigature(host, size) {
    const text = host.dataset.ligatureText || host.textContent.trim()
    if (!text) return

    const geometry = this.runGeometry(text)
    if (!geometry) return

    const height = Math.round(size * 1.6)
    const aspect = geometry.width / geometry.height
    const width = Math.min(900, Math.max(size, Math.round(height * aspect)))

    let canvas = host.querySelector("canvas")
    if (!canvas) {
      canvas = document.createElement("canvas")
      canvas.className = "block"
      host.textContent = ""
      host.appendChild(canvas)
    }
    canvas.style.width = `${width}px`

    const ratio = window.devicePixelRatio || 1
    canvas.width = Math.round(width * ratio)
    canvas.height = Math.round(height * ratio)

    const ctx = canvas.getContext("2d")
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, width, height)

    const pad = 2
    const scale = Math.min((width - pad * 2) / geometry.width, (height - pad * 2) / geometry.height)

    ctx.save()
    ctx.translate(
      width / 2 - (geometry.minX + geometry.width / 2) * scale,
      height / 2 + (geometry.minY + geometry.height / 2) * scale
    )
    ctx.scale(scale, -scale)
    ctx.fillStyle = "#111827"
    geometry.parts.forEach(({ glyph, x, y }) => {
      ctx.save()
      ctx.translate(x, y)
      ctx.beginPath()
      this.tracePath(ctx, glyph.path)
      ctx.fill()
      ctx.restore()
    })
    ctx.restore()
  }

  // Shapes the text with the font's own layout tables, then unions the
  // bounding boxes of the glyphs it produced.
  runGeometry(text) {
    let run
    try {
      run = this.font.layout(text)
    } catch (error) {
      return null
    }
    if (!run?.glyphs?.length) return null

    const parts = []
    let penX = 0
    let penY = 0
    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity

    run.glyphs.forEach((glyph, index) => {
      const position = run.positions[index] || {}
      const x = penX + (position.xOffset || 0)
      const y = penY + (position.yOffset || 0)
      const box = this.glyphBox(glyph)

      if (box) {
        parts.push({ glyph, x, y })
        minX = Math.min(minX, x + box.minX)
        minY = Math.min(minY, y + box.minY)
        maxX = Math.max(maxX, x + box.minX + box.width)
        maxY = Math.max(maxY, y + box.minY + box.height)
      }

      penX += position.xAdvance || 0
      penY += position.yAdvance || 0
    })

    if (!parts.length) return null
    return { parts, minX, minY, width: maxX - minX, height: maxY - minY }
  }

  filterLigatures() {
    const query = this.ligatureSearchTarget.value.trim().toLowerCase()
    this.ligatureRows().forEach((row) => {
      const matches = !query || (row.dataset.ligatureName || "").includes(query)
      row.classList.toggle("hidden", !matches)
    })
    this.updateLigatureCount()
  }

  updateLigatureSize(event) {
    const size = Number(event.target.value)
    if (this.hasLigatureSizeValueTarget) this.ligatureSizeValueTarget.textContent = `${size}px`

    if (this.ligaturesDrawn) {
      this.renderLigaturePreviews()
    } else {
      this.ligaturePreviewTargets.forEach((el) => { el.style.fontSize = `${size}px` })
    }
  }

  ligatureRows() {
    if (!this.hasLigaturesTableTarget) return []
    return Array.from(this.ligaturesTableTarget.querySelectorAll("[data-ligature-row]"))
  }

  updateLigatureCount() {
    if (!this.hasLigatureCountTarget) return
    const rows = this.ligatureRows()
    const visible = rows.filter((row) => !row.classList.contains("hidden")).length
    this.ligatureCountTarget.textContent =
      visible === rows.length ? `${rows.length} ligatures` : `${visible} of ${rows.length} ligatures`
  }

  // ------------------------------------------------------------------- glyphs

  async showGlyphs() {
    if (this.glyphsRendered) return
    if (!this.hasGlyphsContainerTarget) return

    this.glyphsContainerTarget.innerHTML =
      '<div class="glyph-empty">Loading the font…</div>'

    try {
      await this.loadFont()
    } catch (error) {
      this.glyphsContainerTarget.innerHTML =
        `<div class="glyph-empty">This font could not be read in the browser.<br><span class="text-sm">${this.escape(error.message)}</span></div>`
      return
    }

    this.glyphsRendered = true
    this.renderGlyphs()
  }

  filterGlyphs() {
    clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => this.renderGlyphs(), 150)
  }

  updateGlyphZoom(event) {
    this.setGlyphCellSize(Number(event.target.value))
    if (this.glyphsRendered) this.renderGlyphs()
  }

  setGlyphCellSize(size) {
    this.glyphCellSize = size
    if (this.hasGlyphsContainerTarget) {
      this.glyphsContainerTarget.style.setProperty("--glyph-cell", `${size}px`)
    }
  }

  visibleGlyphs() {
    const query = this.hasGlyphSearchTarget ? this.glyphSearchTarget.value.trim().toLowerCase() : ""
    const includeUnmapped = this.hasUnmappedToggleTarget ? this.unmappedToggleTarget.checked : false
    const includeEmpty = this.hasEmptyToggleTarget ? this.emptyToggleTarget.checked : false

    return this.glyphs.filter((entry) => {
      if (!includeUnmapped && !entry.codePoints.length) return false
      if (!includeEmpty && entry.empty) return false
      if (!query) return true
      return entry.haystack.includes(query.replace(/^u\+/, "u+"))
    })
  }

  renderGlyphs() {
    if (!this.hasGlyphsContainerTarget || !this.font) return

    const matches = this.visibleGlyphs()
    const container = this.glyphsContainerTarget
    container.innerHTML = ""

    if (this.hasGlyphCountTarget) {
      this.glyphCountTarget.textContent =
        matches.length === this.glyphs.length
          ? `${this.glyphs.length} glyphs`
          : `${matches.length} of ${this.glyphs.length} glyphs`
    }

    if (this.hasEmptyToggleTarget) {
      const emptyCount = this.glyphs.filter((entry) => entry.empty).length
      this.emptyToggleTarget.closest("label").classList.toggle("hidden", emptyCount === 0)
    }
    if (this.hasUnmappedToggleTarget) {
      const unmappedCount = this.glyphs.filter((entry) => !entry.codePoints.length).length
      this.unmappedToggleTarget.closest("label").classList.toggle("hidden", unmappedCount === 0)
    }

    if (!matches.length) {
      container.innerHTML = '<div class="glyph-empty">No glyph matches that search.</div>'
      return
    }

    const fragment = document.createDocumentFragment()
    // Cap the first paint so a 6k-glyph Mushaf font does not lock up the tab.
    matches.slice(0, 600).forEach((entry) => fragment.appendChild(this.buildGlyphCard(entry)))
    container.appendChild(fragment)

    if (matches.length > 600) {
      const notice = document.createElement("div")
      notice.className = "glyph-empty"
      notice.textContent = `Showing the first 600 of ${matches.length} glyphs — narrow the search to see the rest.`
      container.appendChild(notice)
    }
  }

  buildGlyphCard(entry) {
    const card = document.createElement("button")
    card.type = "button"
    card.className = "glyph-card"
    card.title = entry.hex ? `U+${entry.hex} · ${entry.name}` : entry.name

    // Word ligatures are far wider than they are tall; give them more columns
    // so they are legible instead of shrunk to fit a square cell.
    const box = this.glyphBox(entry.glyph)
    const aspect = box ? box.width / box.height : 1
    const span = aspect > 3.6 ? 3 : aspect > 1.9 ? 2 : 1
    if (span > 1) card.style.gridColumn = `span ${span}`

    const canvas = document.createElement("canvas")
    card.appendChild(canvas)

    const label = document.createElement("span")
    label.className = "glyph-card-label"
    label.textContent = entry.hex ? `U+${entry.hex}` : `#${entry.id}`
    if (entry.codePoints.length > 1) label.textContent += ` +${entry.codePoints.length - 1}`
    card.appendChild(label)

    if (entry.name) {
      const name = document.createElement("span")
      name.className = "glyph-card-name"
      name.textContent = entry.name
      card.appendChild(name)
    }

    card.addEventListener("click", () => this.openGlyphModal(entry))

    // The canvas has no layout width until it is in the document.
    requestAnimationFrame(() => {
      this.drawGlyph(canvas, entry.glyph, canvas.clientWidth || this.glyphCellSize * span, Math.round(this.glyphCellSize * 0.72))
    })

    return card
  }

  // Draws the outline scaled to its own bounding box, so a wide word ligature
  // and a narrow harakah both fill their cell instead of being clipped.
  drawGlyph(canvas, glyph, cssWidth, cssHeight) {
    const ratio = window.devicePixelRatio || 1
    canvas.width = Math.max(1, Math.round(cssWidth * ratio))
    canvas.height = Math.max(1, Math.round(cssHeight * ratio))
    canvas.style.height = `${cssHeight}px`

    const ctx = canvas.getContext("2d")
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, cssWidth, cssHeight)

    const box = this.glyphBox(glyph)
    if (!box) {
      ctx.fillStyle = "#cbd5e1"
      ctx.font = "11px system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText("no outline", cssWidth / 2, cssHeight / 2)
      return
    }

    const pad = Math.max(6, Math.min(cssWidth, cssHeight) * 0.12)
    const scale = Math.min((cssWidth - pad * 2) / box.width, (cssHeight - pad * 2) / box.height)

    ctx.save()
    ctx.translate(
      cssWidth / 2 - (box.minX + box.width / 2) * scale,
      cssHeight / 2 + (box.minY + box.height / 2) * scale
    )
    ctx.scale(scale, -scale)
    ctx.fillStyle = "#1f2937"
    ctx.beginPath()
    this.tracePath(ctx, glyph.path)
    ctx.fill()
    ctx.restore()
  }

  // Some fonts ship a zeroed glyf bounding box, so measure the outline itself
  // first and only fall back to the box recorded in the table.
  glyphBox(glyph) {
    for (const source of [() => glyph.path.bbox, () => glyph.bbox]) {
      let bbox
      try {
        bbox = source()
      } catch (error) {
        continue
      }
      if (!bbox) continue

      const width = bbox.maxX - bbox.minX
      const height = bbox.maxY - bbox.minY
      if (width > 0 && height > 0) return { minX: bbox.minX, minY: bbox.minY, width, height }
    }
    return null
  }

  tracePath(ctx, path) {
    if (!path || !Array.isArray(path.commands)) return
    for (const { command, args } of path.commands) {
      switch (command) {
        case "moveTo": ctx.moveTo(args[0], args[1]); break
        case "lineTo": ctx.lineTo(args[0], args[1]); break
        case "quadraticCurveTo": ctx.quadraticCurveTo(args[0], args[1], args[2], args[3]); break
        case "bezierCurveTo": ctx.bezierCurveTo(args[0], args[1], args[2], args[3], args[4], args[5]); break
        case "closePath": ctx.closePath(); break
      }
    }
  }

  // -------------------------------------------------------------- glyph modal

  openGlyphModal(entry) {
    this.closeGlyphModal()

    const overlay = document.createElement("div")
    overlay.className = "glyph-modal"
    overlay.addEventListener("click", (event) => {
      if (event.target === overlay) this.closeGlyphModal()
    })

    const title = entry.hex ? `U+${entry.hex}` : `Glyph #${entry.id}`
    overlay.innerHTML = `
      <div class="glyph-modal-panel" role="dialog" aria-modal="true" aria-label="${this.escape(title)}">
        <div class="glyph-modal-header">
          <div>
            <h3 class="text-lg font-semibold text-gray-900 m-0">${this.escape(title)}</h3>
            <p class="text-sm text-gray-500 m-0" data-glyph-subtitle>${this.escape(entry.name || "unnamed glyph")}</p>
          </div>
          <button type="button" class="btn btn-secondary btn-sm" data-glyph-close>Close</button>
        </div>
        <div class="grid gap-5 p-5 md:grid-cols-2">
          <div class="rounded-lg border border-gray-200 bg-gray-50 p-3">
            <canvas data-glyph-canvas class="block w-full"></canvas>
          </div>
          <dl class="m-0" data-glyph-meta></dl>
        </div>
      </div>
    `

    document.body.appendChild(overlay)
    document.body.style.overflow = "hidden"
    this.glyphModal = overlay

    overlay.querySelector("[data-glyph-close]").addEventListener("click", () => this.closeGlyphModal())
    this.escapeHandler = (event) => { if (event.key === "Escape") this.closeGlyphModal() }
    document.addEventListener("keydown", this.escapeHandler)

    const canvas = overlay.querySelector("[data-glyph-canvas]")
    requestAnimationFrame(() => this.drawGlyph(canvas, entry.glyph, canvas.clientWidth || 320, 280))

    this.fillGlyphMeta(overlay.querySelector("[data-glyph-meta]"), entry)
    this.appendUnicodeName(overlay, entry)
  }

  // The official Unicode name is not in the font, so ask the API for it.
  async appendUnicodeName(overlay, entry) {
    if (!entry.hex) return
    try {
      const response = await fetch(`/api/v1/unicode/name?code_point=${entry.hex}`)
      if (!response.ok) return
      const info = await response.json()
      if (!info?.name || overlay !== this.glyphModal) return

      const subtitle = overlay.querySelector("[data-glyph-subtitle]")
      if (subtitle) subtitle.textContent = `${info.name} · ${entry.name || "unnamed glyph"}`
    } catch (error) {
      // The name is a nice-to-have; leave the glyph name on its own.
    }
  }

  fillGlyphMeta(list, entry) {
    const rows = [
      ["Glyph index", `${entry.id}`, `${entry.id}`],
      ["Glyph name", entry.name || "—", entry.name],
      ["Unicode", entry.hex ? `U+${entry.hex}` : "not mapped", entry.hex ? `U+${entry.hex}` : null],
      ["Character", entry.char || "—", entry.char || null],
      ["HTML entity", entry.codePoints.length ? `&#x${entry.hex};` : "—", entry.codePoints.length ? `&#x${entry.hex};` : null],
      ["Advance width", `${Math.round(entry.glyph.advanceWidth)} units`, null]
    ]

    const others = entry.codePoints.filter((cp) => cp !== entry.primary)
    if (others.length) {
      rows.push(["Also mapped from", others.map((cp) => `U+${this.toHex(cp)}`).join(", "), null])
    }

    list.innerHTML = rows
      .map(([label, value, copyValue]) => `
        <div class="glyph-meta-row">
          <dt>${this.escape(label)}</dt>
          <dd class="flex items-center gap-2">
            <span>${this.escape(value)}</span>
            ${copyValue ? `<button type="button" class="docs-copy-btn" data-copy-value="${this.escape(copyValue)}">Copy</button>` : ""}
          </dd>
        </div>
      `)
      .join("")

    if (entry.hex) {
      list.insertAdjacentHTML("beforeend", `
        <div class="pt-3">
          <a class="text-blue-600 underline" target="_blank" rel="noopener noreferrer"
             href="https://www.compart.com/en/unicode/U+${entry.hex}">Look this character up on Compart</a>
        </div>
      `)
    }

    list.querySelectorAll("[data-copy-value]").forEach((button) => {
      button.addEventListener("click", () => this.copyText(button.dataset.copyValue, button))
    })
  }

  closeGlyphModal() {
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }
    if (this.glyphModal) {
      this.glyphModal.remove()
      this.glyphModal = null
      document.body.style.overflow = ""
    }
  }

  // -------------------------------------------------------------------- copy

  copyValue(event) {
    const button = event.currentTarget
    this.copyText(button.dataset.copyValue, button)
  }

  copyCode(event) {
    const button = event.currentTarget
    const code = button.closest(".docs-code")?.querySelector("code")
    if (code) this.copyText(code.textContent, button)
  }

  async copyText(text, button) {
    if (text == null) return
    try {
      await navigator.clipboard.writeText(text)
    } catch (error) {
      const area = document.createElement("textarea")
      area.value = text
      area.style.position = "fixed"
      area.style.opacity = "0"
      document.body.appendChild(area)
      area.select()
      document.execCommand("copy")
      area.remove()
    }

    if (!button) return
    const original = button.textContent
    button.textContent = "Copied"
    button.classList.add("text-[#46ac7a]")
    setTimeout(() => {
      button.textContent = original
      button.classList.remove("text-[#46ac7a]")
    }, 1500)
  }

  escape(value) {
    return String(value ?? "").replace(/[&<>"']/g, (char) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[char])
  }
}

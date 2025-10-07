import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["glyphsContainer", "sampleText", "glyphSearch", "fontSizeSlider", "fontSizeValue", "sampleTextInput", "ligaturesTable"]
  static values = { 
    fontUrl: String, 
    fontFace: String, 
    sampleText: String 
  }

  connect() {
    this.fontLoaded = false
    this.fontData = null
    this.debounceTimer = null
    
    this.loadFont()
    this.setupEventListeners()
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  loadFont() {
    if (typeof opentype === 'undefined') {
      this.showPlaceholderMessage()
      return
    }

    opentype.load(this.fontUrlValue, (err, font) => {
      if (err) {
        this.showPlaceholderMessage()
        return
      }

      this.fontData = font
      this.fontLoaded = true

      // Render glyphs if glyphs tab is already active
      if (this.isGlyphsTabActive()) {
        this.renderGlyphs()
      }
    })
  }

  setupEventListeners() {
    try {
      // Sample text input
      if (this.hasSampleTextInputTarget && this.hasSampleTextTarget) {
        this.sampleTextInputTarget.addEventListener('input', (e) => {
          this.sampleTextTarget.textContent = e.target.value
        })
      }

      // Font size slider
      if (this.hasFontSizeSliderTarget && this.hasFontSizeValueTarget && this.hasSampleTextTarget) {
        this.fontSizeSliderTarget.addEventListener('input', (e) => {
          const fontSize = e.target.value + "px"
          this.sampleTextTarget.style.fontSize = fontSize
          this.fontSizeValueTarget.textContent = fontSize
        })
      }

      // Glyph search
      if (this.hasGlyphSearchTarget) {
        this.glyphSearchTarget.addEventListener('input', (e) => {
          clearTimeout(this.debounceTimer)
          this.debounceTimer = setTimeout(() => {
            this.renderGlyphs(e.target.value.trim())
          }, 200)
        })
      }

      // Tab events
      this.setupTabEvents()
    } catch (error) {
      // Silently handle errors in production
    }
  }

  setupTabEvents() {
    try {
      const glyphsTab = document.getElementById('tab-glyphs')
      const glyphsPane = document.getElementById('tab-glyphs-pane')
      
      if (glyphsTab) {
        // Bootstrap tab events
        glyphsTab.addEventListener('shown.bs.tab', () => {
          if (this.fontLoaded && this.fontData) {
            this.renderGlyphs()
          }
        })
        
        // Click event as backup
        glyphsTab.addEventListener('click', () => {
          setTimeout(() => {
            if (this.fontLoaded && this.fontData) {
              this.renderGlyphs()
            }
          }, 100)
        })
      }
      
      if (glyphsPane) {
        // Mutation observer to watch for tab content changes
        const observer = new MutationObserver((mutations) => {
          mutations.forEach((mutation) => {
            if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
              if (glyphsPane.classList.contains('active') && glyphsPane.classList.contains('show')) {
                if (this.fontLoaded && this.fontData) {
                  this.renderGlyphs()
                }
              }
            }
          })
        })
        
        observer.observe(glyphsPane, { attributes: true, attributeFilter: ['class'] })
      }
    } catch (error) {
      // Silently handle errors in production
    }
  }

  isGlyphsTabActive() {
    const glyphsPane = document.getElementById('tab-glyphs-pane')
    return glyphsPane && glyphsPane.classList.contains('active') && glyphsPane.classList.contains('show')
  }

  renderGlyphs(query = '') {
    try {
      if (!this.fontData || !this.hasGlyphsContainerTarget) {
        if (this.hasGlyphsContainerTarget) {
          this.glyphsContainerTarget.innerHTML = '<div class="tw-text-center tw-p-4 tw-text-gray-500">Loading glyphs...</div>'
          this.removeGridClasses()
        }
        return
      }
      
      // Restore grid classes when showing actual glyphs
      this.restoreGridClasses()
      this.glyphsContainerTarget.innerHTML = ''
      
      Object.values(this.fontData.glyphs.glyphs).forEach(glyph => {
        if (!glyph.unicode) return

        const unicodeHex = glyph.unicode.toString(16).toUpperCase()
        if (!unicodeHex.includes(query.toUpperCase())) return

        const glyphChar = String.fromCharCode(glyph.unicode)
        const el = document.createElement('div')
        el.className = 'tw-text-center tw-p-2 tw-border tw-border-gray-300 tw-rounded'
        el.style.fontFamily = this.fontFaceValue
        el.innerHTML = `
          <div class="tw-text-3xl tw-mb-2" dir="rtl">${glyphChar}</div>
          <div class="tw-text-xs tw-text-gray-500">U+${unicodeHex}</div>
        `
        this.glyphsContainerTarget.appendChild(el)
      })
    } catch (error) {
      if (this.hasGlyphsContainerTarget) {
        this.glyphsContainerTarget.innerHTML = '<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-4 tw-text-gray-500">Error loading glyphs</div></div>'
        this.removeGridClasses()
      }
    }
  }

  showPlaceholderMessage() {
    try {
      const placeholderHTML = '<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-8 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300 tw-max-w-md tw-mx-auto"><div class="tw-text-lg tw-font-medium tw-mb-2 tw-px-2">Preview is not available for this font</div><div class="tw-text-sm">The TTF font file could not be loaded</div></div></div>'
      
      if (this.hasGlyphsContainerTarget) {
        this.glyphsContainerTarget.innerHTML = placeholderHTML
        this.removeGridClasses()
      }
      
      if (this.hasSampleTextTarget) {
        this.sampleTextTarget.innerHTML = '<div class="tw-text-center tw-p-4 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300"><div class="tw-text-sm">Preview is not available for this font</div></div>'
      }
      
      if (this.hasLigaturesTableTarget) {
        this.ligaturesTableTarget.innerHTML = '<tr><td colspan="4" class="tw-text-center tw-p-8 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300"><div class="tw-text-lg tw-font-medium tw-mb-2">Preview is not available for this font</div><div class="tw-text-sm">The TTF font file could not be loaded</div></td></tr>'
      }
    } catch (error) {
      // Silently handle errors in production
    }
  }

  // Helper methods for grid classes management
  removeGridClasses() {
    if (this.hasGlyphsContainerTarget) {
      const gridClasses = this.glyphsContainerTarget.dataset.fontPreviewGridClasses
      if (gridClasses) {
        const classes = gridClasses.split(' ')
        classes.forEach(className => {
          this.glyphsContainerTarget.classList.remove(className)
        })
      }
    }
  }

  restoreGridClasses() {
    if (this.hasGlyphsContainerTarget) {
      const gridClasses = this.glyphsContainerTarget.dataset.fontPreviewGridClasses
      if (gridClasses) {
        const classes = gridClasses.split(' ')
        classes.forEach(className => {
          this.glyphsContainerTarget.classList.add(className)
        })
      }
    }
  }

  // Public method to manually trigger glyph rendering
  refreshGlyphs() {
    if (this.fontLoaded && this.fontData) {
      this.renderGlyphs()
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import * as fontkit from "fontkit"
import { Buffer } from "buffer"

window.Buffer = Buffer

export default class extends Controller {
  static targets = ["glyphsContainer", "sampleText", "glyphSearch", "fontSizeSlider", "fontSizeValue", "sampleTextInput", "ligaturesTable"]
  static values = { 
    fontUrl: String, 
    fontFormat: String,
    fontFace: String, 
    sampleText: String 
  }

  connect() {
    this.fontLoaded = false
    this.fontData = null
    this.fontLoadError = false
    this.loadingFont = false
    this.debounceTimer = null
    this.fontLoadingInterval = null
    this.fontLoadingTimeout = null
    
    this.loadFont()
    this.setupEventListeners()
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.fontLoadingInterval) {
      clearInterval(this.fontLoadingInterval)
    }
    if (this.fontLoadingTimeout) {
      clearTimeout(this.fontLoadingTimeout)
    }
  }

  loadFont() {
    if (this.loadingFont) {
      return
    }

    this.loadingFont = true

    fetch(this.fontUrlValue)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.arrayBuffer()
      })
      .then(arrayBuffer => {
        try {
          if (!(arrayBuffer instanceof ArrayBuffer)) {
            throw new Error('Expected ArrayBuffer')
          }

          const buffer = Buffer.from(arrayBuffer)
          
          if (!buffer.buffer || !(buffer.buffer instanceof ArrayBuffer)) {
            throw new Error('Buffer does not have valid ArrayBuffer backing')
          }

          const font = fontkit.create(buffer)
          
          this.fontData = font
          this.fontLoaded = true
          this.fontLoadError = false
          this.loadingFont = false

          if (this.isGlyphsTabActive()) {
            this.renderGlyphs()
          }
        } catch (error) {
          console.error('Error parsing font:', error)
          console.error('Error details:', {
            arrayBufferType: arrayBuffer?.constructor?.name,
            isArrayBuffer: arrayBuffer instanceof ArrayBuffer,
            bufferAvailable: typeof Buffer !== 'undefined',
            fontkitAvailable: typeof fontkit !== 'undefined'
          })
          this.fontLoadError = true
          this.loadingFont = false
          if (this.isGlyphsTabActive()) {
            this.showPlaceholderMessage()
          }
        }
      })
      .catch(error => {
        console.error('Error loading font:', error)
        this.fontLoadError = true
        this.loadingFont = false
        if (this.isGlyphsTabActive()) {
          this.showPlaceholderMessage()
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
        glyphsTab.addEventListener('shown.bs.tab', () => {
          this.handleGlyphsTabShown()
        })
        
        // Click event as backup
        glyphsTab.addEventListener('click', () => {
          setTimeout(() => {
            this.handleGlyphsTabShown()
          }, 100)
        })
      }
      
      if (glyphsPane) {
        // Mutation observer to watch for tab content changes
        const observer = new MutationObserver((mutations) => {
          mutations.forEach((mutation) => {
            if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
              if (glyphsPane.classList.contains('active') && glyphsPane.classList.contains('show')) {
                this.handleGlyphsTabShown()
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

  handleGlyphsTabShown() {
    if (this.fontLoaded && this.fontData) {
      // Font is already loaded, render glyphs immediately
      this.renderGlyphs()
    } else {
      // Font is still loading, show loading message and wait
      this.showLoadingMessage()
      this.waitForFontAndRender()
    }
  }

  showLoadingMessage() {
    if (this.hasGlyphsContainerTarget) {
      this.glyphsContainerTarget.innerHTML = '<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-4 tw-text-gray-500"><div class="tw-animate-spin tw-rounded-full tw-h-12 tw-w-12 tw-border-b-2 tw-border-blue-500 tw-mx-auto tw-mb-4"></div><div>Loading font and glyphs...</div></div></div>'
      this.removeGridClasses()
    }
  }

  waitForFontAndRender() {
    // Clear any existing intervals/timeouts
    if (this.fontLoadingInterval) {
      clearInterval(this.fontLoadingInterval)
    }
    if (this.fontLoadingTimeout) {
      clearTimeout(this.fontLoadingTimeout)
    }

    let checkCount = 0
    const maxChecks = 300 // 30 seconds (300 * 100ms)

    // Check every 100ms if font is loaded
    this.fontLoadingInterval = setInterval(() => {
      checkCount++

      if (this.fontLoaded && this.fontData) {
        clearInterval(this.fontLoadingInterval)
        this.fontLoadingInterval = null
        if (this.isGlyphsTabActive()) {
          this.renderGlyphs()
        }
      } else if (this.fontLoadError) {
        // Font failed to load
        clearInterval(this.fontLoadingInterval)
        this.fontLoadingInterval = null
        if (this.isGlyphsTabActive()) {
          this.showPlaceholderMessage()
        }
      } else if (checkCount >= maxChecks) {
        // Timeout reached
        clearInterval(this.fontLoadingInterval)
        this.fontLoadingInterval = null
        if (this.isGlyphsTabActive()) {
          this.showPlaceholderMessage()
        }
      }
    }, 100)
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
      
      // Ensure CSS font is also loaded before rendering
      if (document.fonts && this.fontFaceValue) {
        document.fonts.load(`12px "${this.fontFaceValue}"`).then(() => {
          this.actuallyRenderGlyphs(query)
        }).catch(() => {
          // Still try to render even if font face loading fails
          this.actuallyRenderGlyphs(query)
        })
      } else {
        // Fallback if Font Loading API is not supported
        this.actuallyRenderGlyphs(query)
      }
    } catch (error) {
      if (this.hasGlyphsContainerTarget) {
        this.glyphsContainerTarget.innerHTML = '<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-4 tw-text-gray-500">Error loading glyphs</div></div>'
        this.removeGridClasses()
      }
    }
  }

  actuallyRenderGlyphs(query = '') {
    try {
      this.restoreGridClasses()
      this.glyphsContainerTarget.innerHTML = ''
      
      if (!this.fontData || !this.fontData.characterSet) {
        throw new Error('Font data not available')
      }

      const glyphs = []
      this.fontData.characterSet.forEach(unicode => {
        const glyph = this.fontData.glyphForCodePoint(unicode)
        if (!glyph) return

        const unicodeHex = unicode.toString(16).toUpperCase().padStart(4, '0')
        if (query && !unicodeHex.includes(query.toUpperCase())) return

        try {
          const glyphChar = String.fromCodePoint(unicode)
          glyphs.push({ unicode, unicodeHex, glyphChar, glyph })
        } catch (e) {
          return
        }
      })

      glyphs.sort((a, b) => a.unicode - b.unicode)

      glyphs.forEach(({ unicodeHex, glyphChar, glyph }) => {
        const el = document.createElement('div')
        el.className = 'tw-text-center tw-p-2 tw-border tw-border-gray-300 tw-rounded tw-cursor-pointer hover:tw-bg-gray-100 tw-transition-colors'
        el.style.fontFamily = this.fontFaceValue
        el.onclick = () => this.showGlyphDetails(glyph, unicodeHex, glyphChar)
        el.innerHTML = `
          <div class="tw-text-3xl tw-mb-2" dir="rtl">${glyphChar}</div>
          <div class="tw-text-xs tw-text-gray-500">U+${unicodeHex}</div>
        `
        this.glyphsContainerTarget.appendChild(el)
      })
    } catch (error) {
      console.error('Error rendering glyphs:', error)
      if (this.hasGlyphsContainerTarget) {
        this.glyphsContainerTarget.innerHTML = '<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-4 tw-text-gray-500">Error loading glyphs</div></div>'
        this.removeGridClasses()
      }
    }
  }

  showGlyphDetails(glyph, unicodeHex, glyphChar) {
    let overlay = document.getElementById('glyph-details-overlay')
    if (!overlay) {
      overlay = this.createGlyphOverlay()
    }

    const canvas = document.getElementById('glyph-outline-canvas')
    const unicodeEl = document.getElementById('glyph-unicode')
    const charEl = document.getElementById('glyph-char')
    const metadataEl = document.getElementById('glyph-metadata')

    if (unicodeEl) unicodeEl.textContent = `U+${unicodeHex}`
    if (charEl) {
      charEl.textContent = glyphChar
      charEl.style.fontFamily = this.fontFaceValue
    }

    const pathType = glyph.path ? 
      (glyph.path.commands ? 'TrueType (glyf)' : 
       glyph.path.toSVG ? 'PostScript (CFF)' : 
       'Unknown') : 'N/A'
    
    const metadata = {
      'Unicode': `U+${unicodeHex}`,
      'Character': glyphChar,
      'Glyph ID': glyph.id || 'N/A',
      'Advance Width': glyph.advanceWidth || 'N/A',
      'Left Side Bearing': glyph.leftSideBearing !== undefined ? glyph.leftSideBearing : 'N/A',
      'Right Side Bearing': glyph.rightSideBearing !== undefined ? glyph.rightSideBearing : 'N/A',
      'Bounding Box': glyph.bbox ? `${glyph.bbox.minX}, ${glyph.bbox.minY} to ${glyph.bbox.maxX}, ${glyph.bbox.maxY}` : 'N/A',
      'Path Type': pathType,
      'Has Outline': glyph.path ? 'Yes' : 'No'
    }

    if (metadataEl) {
      metadataEl.innerHTML = Object.entries(metadata).map(([key, value]) => 
        `<div class="tw-flex tw-justify-between tw-py-2 tw-border-b tw-border-gray-200"><span class="tw-font-semibold tw-text-gray-700">${key}:</span><span class="tw-text-gray-600">${value}</span></div>`
      ).join('')
    }

    overlay.classList.remove('tw-hidden')
    overlay.style.display = 'flex'
    document.body.style.overflow = 'hidden'

    setTimeout(() => {
    if (canvas) {
      this.renderGlyphOutline(canvas, glyph)
    }
    }, 50)
  }

  closeGlyphOverlay() {
    const overlay = document.getElementById('glyph-details-overlay')
    if (overlay) {
      overlay.classList.add('tw-hidden')
      overlay.style.display = 'none'
      document.body.style.overflow = ''
    }
  }

  renderGlyphOutline(canvas, glyph) {
    if (!canvas) {
      console.error('Canvas is null')
      return
    }

    const ctx = canvas.getContext('2d')
    if (!ctx) {
      console.error('Could not get 2d context')
      return
    }

    const size = 400
    const padding = 40

    if (canvas.width !== size || canvas.height !== size) {
      canvas.width = size
      canvas.height = size
    }

    ctx.clearRect(0, 0, size, size)
    ctx.fillStyle = '#f8f9fa'
    ctx.fillRect(0, 0, size, size)


    if (!glyph) {
      ctx.fillStyle = '#666'
      ctx.font = '16px Arial'
      ctx.textAlign = 'center'
      ctx.fillText('No glyph data', size / 2, size / 2)
      return
    }

    const bbox = glyph.bbox || { minX: 0, minY: -800, maxX: glyph.advanceWidth || 1000, maxY: 200 }
    const width = Math.abs(bbox.maxX - bbox.minX) || 1000
    const height = Math.abs(bbox.maxY - bbox.minY) || 1000
    
    if (width === 0 || height === 0) {
      ctx.fillStyle = '#666'
      ctx.font = '16px Arial'
      ctx.textAlign = 'center'
      ctx.fillText('Invalid bounding box', size / 2, size / 2)
      return
    }

    const actualScale = Math.min(
      (size - padding * 2) / width,
      (size - padding * 2) / height
    )

    ctx.save()
    ctx.translate(
      size / 2 - (bbox.minX + width / 2) * actualScale,
      size / 2 + (bbox.minY + height / 2) * actualScale
    )
    ctx.scale(actualScale, -actualScale)

    if (!glyph.path) {
      if (glyph.isComposite && glyph.components) {
        this.renderCompositeGlyph(ctx, glyph, size, padding, actualScale)
        ctx.restore()
        ctx.strokeStyle = '#ddd'
        ctx.lineWidth = 1
        ctx.setLineDash([])
        ctx.beginPath()
        ctx.moveTo(size / 2, 0)
        ctx.lineTo(size / 2, size)
        ctx.moveTo(0, size / 2)
        ctx.lineTo(size, size / 2)
        ctx.stroke()
        return
      }
      ctx.restore()
      ctx.fillStyle = '#666'
      ctx.font = '16px Arial'
      ctx.textAlign = 'center'
      ctx.fillText('No outline available', size / 2, size / 2)
      return
    }

    ctx.strokeStyle = '#999'
    ctx.lineWidth = Math.max(1, 20 / actualScale)
    ctx.setLineDash([])
    ctx.fillStyle = '#f5f5f5'

    const path = glyph.path
    let pathRendered = false


    try {
      if (path) {
        if (path.contours && Array.isArray(path.contours) && path.contours.length > 0) {
          ctx.beginPath()
          path.contours.forEach(contour => {
            if (contour && contour.points && Array.isArray(contour.points)) {
              const points = contour.points
              if (points.length > 0) {
                const firstPoint = points[0]
                ctx.moveTo(firstPoint.x || 0, firstPoint.y || 0)
                
                for (let i = 1; i < points.length; i++) {
                  const p = points[i]
                  const prevP = points[i - 1]
                  
                  if (p.onCurve) {
                    ctx.lineTo(p.x || 0, p.y || 0)
                  } else {
                    const nextP = i + 1 < points.length ? points[i + 1] : firstPoint
                    const controlX = p.x || 0
                    const controlY = p.y || 0
                    const endX = nextP.onCurve ? (nextP.x || 0) : (controlX + (nextP.x || 0)) / 2
                    const endY = nextP.onCurve ? (nextP.y || 0) : (controlY + (nextP.y || 0)) / 2
                    ctx.quadraticCurveTo(controlX, controlY, endX, endY)
                    if (nextP.onCurve) i++
                  }
                }
                ctx.closePath()
              }
            }
          })
          ctx.fill()
          ctx.stroke()
          pathRendered = true
        } else if (path.commands && Array.isArray(path.commands) && path.commands.length > 0) {
          ctx.beginPath()
          let hasValidCommands = false
          
          path.commands.forEach((cmd, index) => {
            try {
              if (cmd && typeof cmd === 'object') {
                if (cmd.type === 'M' || cmd.type === 'moveTo' || (cmd.x !== undefined && cmd.y !== undefined && index === 0)) {
                  const x = cmd.x !== undefined ? cmd.x : 0
                  const y = cmd.y !== undefined ? cmd.y : 0
                  ctx.moveTo(x, y)
                  hasValidCommands = true
                } else if (cmd.type === 'L' || cmd.type === 'lineTo') {
                  ctx.lineTo(cmd.x || 0, cmd.y || 0)
                  hasValidCommands = true
                } else if (cmd.type === 'Q' || cmd.type === 'quadraticCurveTo') {
                  ctx.quadraticCurveTo(cmd.x1 || 0, cmd.y1 || 0, cmd.x || 0, cmd.y || 0)
                  hasValidCommands = true
                } else if (cmd.type === 'C' || cmd.type === 'bezierCurveTo') {
                  ctx.bezierCurveTo(
                    cmd.x1 || 0, cmd.y1 || 0,
                    cmd.x2 || 0, cmd.y2 || 0,
                    cmd.x || 0, cmd.y || 0
                  )
                  hasValidCommands = true
                } else if (cmd.type === 'Z' || cmd.type === 'closePath') {
                  ctx.closePath()
                  hasValidCommands = true
                } else {
                  console.warn(`Unknown command type at index ${index}:`, cmd)
                }
              }
            } catch (cmdError) {
              console.warn(`Error processing command ${index}:`, cmdError, cmd)
            }
          })
          
          if (hasValidCommands) {
            ctx.fill()
            ctx.stroke()
            pathRendered = true
          }
        }

        if (!pathRendered && typeof path.toSVG === 'function') {
          try {
            const svgResult = path.toSVG()
            
            if (typeof svgResult === 'string' && svgResult.trim().length > 0) {
              let pathData = null
              const trimmed = svgResult.trim()
              
              const pathMatch = trimmed.match(/d\s*=\s*["']([^"']*)["']/)
              if (pathMatch && pathMatch[1]) {
                pathData = pathMatch[1]
              } else if (trimmed.match(/^[MmLlHhVvCcSsQqTtAaZz]/)) {
                pathData = trimmed
              } else if (trimmed.includes('<path')) {
                const pathElementMatch = trimmed.match(/<path[^>]*d\s*=\s*["']([^"']*)["']/i)
                if (pathElementMatch && pathElementMatch[1]) {
                  pathData = pathElementMatch[1]
                }
              }
              
              if (pathData && pathData.length > 0) {
                this.renderSVGPath(ctx, pathData)
                pathRendered = true
              }
            } else if (svgResult && typeof svgResult === 'object' && svgResult.d) {
              this.renderSVGPath(ctx, svgResult.d)
              pathRendered = true
            }
          } catch (svgError) {
            console.error('SVG path failed:', svgError)
          }
        }

        if (!pathRendered && path.segments && Array.isArray(path.segments) && path.segments.length > 0) {
          ctx.beginPath()
          path.segments.forEach((segment, index) => {
            try {
              if (segment && segment.points) {
                const points = Array.isArray(segment.points) ? segment.points : [segment.points]
                if (points.length > 0) {
                  const firstPoint = points[0]
                  if (index === 0) {
                    ctx.moveTo(firstPoint.x || 0, firstPoint.y || 0)
                  }
                  if (points.length === 1) {
                    ctx.lineTo(firstPoint.x || 0, firstPoint.y || 0)
                  } else if (points.length === 2) {
                    ctx.quadraticCurveTo(
                      points[0].x || 0, points[0].y || 0,
                      points[1].x || 0, points[1].y || 0
                    )
                  } else if (points.length === 3) {
                    ctx.bezierCurveTo(
                      points[0].x || 0, points[0].y || 0,
                      points[1].x || 0, points[1].y || 0,
                      points[2].x || 0, points[2].y || 0
                    )
                  }
                }
              }
            } catch (segError) {
              console.warn(`Error processing segment ${index}:`, segError)
            }
          })
          ctx.fill()
          ctx.stroke()
          pathRendered = true
        }

        if (!pathRendered && path.toPath2D && typeof path.toPath2D === 'function') {
          try {
            const path2d = path.toPath2D()
            ctx.fill(path2d)
            ctx.stroke(path2d)
            pathRendered = true
            console.log('Path rendered using Path2D')
          } catch (path2dError) {
            console.warn('Path2D failed:', path2dError)
          }
        }
      }

      if (!pathRendered) {
        if (glyph.isComposite && glyph.components) {
          this.renderCompositeGlyph(ctx, glyph, size, padding, actualScale)
          pathRendered = true
        } else {
          ctx.fillStyle = '#666'
          ctx.font = `${16 / actualScale}px Arial`
          ctx.textAlign = 'center'
          ctx.fillText('No outline available', 0, 0)
        }
      }
    } catch (error) {
      console.error('Error rendering path:', error, error.stack)
      ctx.fillStyle = '#666'
      ctx.font = `${16 / actualScale}px Arial`
      ctx.textAlign = 'center'
      ctx.fillText('Error rendering outline', 0, 0)
    }

    ctx.restore()

    ctx.strokeStyle = '#ddd'
    ctx.lineWidth = 1
    ctx.setLineDash([])
    ctx.beginPath()
    ctx.moveTo(size / 2, 0)
    ctx.lineTo(size / 2, size)
    ctx.moveTo(0, size / 2)
    ctx.lineTo(size, size / 2)
    ctx.stroke()
  }

  renderCompositeGlyph(ctx, glyph, size, padding, scale) {
    if (!glyph.components || !Array.isArray(glyph.components) || glyph.components.length === 0) {
      return
    }
    
    glyph.components.forEach((component, index) => {
      try {
        const componentGlyph = component.glyph || component
        if (componentGlyph) {
          ctx.save()
          
          if (component.xOffset !== undefined || component.yOffset !== undefined) {
            ctx.translate(component.xOffset || 0, component.yOffset || 0)
          }
          
          if (component.transform) {
            ctx.transform(
              component.transform.xx || 1, component.transform.yx || 0,
              component.transform.xy || 0, component.transform.yy || 1,
              component.transform.dx || 0, component.transform.dy || 0
            )
          }
          
          if (componentGlyph.path) {
            const compPath = componentGlyph.path
            
            if (compPath.contours && Array.isArray(compPath.contours) && compPath.contours.length > 0) {
              compPath.contours.forEach(contour => {
                if (contour && contour.points && Array.isArray(contour.points)) {
                  const points = contour.points
                  if (points.length > 0) {
                    ctx.beginPath()
                    ctx.moveTo(points[0].x || 0, points[0].y || 0)
                    for (let i = 1; i < points.length; i++) {
                      const p = points[i]
                      if (p.onCurve) {
                        ctx.lineTo(p.x || 0, p.y || 0)
                      } else if (i + 1 < points.length && !points[i + 1].onCurve) {
                        const nextP = points[i + 1]
                        ctx.quadraticCurveTo(p.x || 0, p.y || 0, nextP.x || 0, nextP.y || 0)
                        i++
                      } else if (i + 1 < points.length) {
                        const nextP = points[i + 1]
                        ctx.quadraticCurveTo(p.x || 0, p.y || 0, nextP.x || 0, nextP.y || 0)
                        i++
                      }
                    }
                    ctx.closePath()
                    ctx.fill()
                    ctx.stroke()
                  }
                }
              })
            } else if (compPath.commands && Array.isArray(compPath.commands) && compPath.commands.length > 0) {
              ctx.beginPath()
              compPath.commands.forEach(cmd => {
                if (cmd.type === 'M' || cmd.type === 'moveTo') {
                  ctx.moveTo(cmd.x || 0, cmd.y || 0)
                } else if (cmd.type === 'L' || cmd.type === 'lineTo') {
                  ctx.lineTo(cmd.x || 0, cmd.y || 0)
                } else if (cmd.type === 'Q' || cmd.type === 'quadraticCurveTo') {
                  ctx.quadraticCurveTo(cmd.x1 || 0, cmd.y1 || 0, cmd.x || 0, cmd.y || 0)
                } else if (cmd.type === 'C' || cmd.type === 'bezierCurveTo') {
                  ctx.bezierCurveTo(cmd.x1 || 0, cmd.y1 || 0, cmd.x2 || 0, cmd.y2 || 0, cmd.x || 0, cmd.y || 0)
                } else if (cmd.type === 'Z' || cmd.type === 'closePath') {
                  ctx.closePath()
                }
              })
              ctx.fill()
              ctx.stroke()
            } else if (typeof compPath.toSVG === 'function') {
              const svgResult = compPath.toSVG()
              if (typeof svgResult === 'string' && svgResult.trim().length > 0) {
                const trimmed = svgResult.trim()
                const pathMatch = trimmed.match(/d\s*=\s*["']([^"']*)["']/)
                const pathData = pathMatch && pathMatch[1] ? pathMatch[1] : (trimmed.match(/^[MmLlHhVvCcSsQqTtAaZz]/) ? trimmed : null)
                if (pathData) {
                  this.renderSVGPath(ctx, pathData)
                }
              }
            }
          }
          
          ctx.restore()
        }
      } catch (compError) {
        console.warn(`Error rendering component ${index}:`, compError)
      }
    })
  }

  renderSVGPath(ctx, pathData) {
    if (!pathData || typeof pathData !== 'string') {
      console.error('Invalid pathData:', pathData)
      return
    }

    const commands = pathData.match(/[MmLlHhVvCcSsQqTtAaZz][^MmLlHhVvCcSsQqTtAaZz]*/g) || []
    
    if (commands.length === 0) {
      console.warn('No commands found in path data')
      return
    }

    let currentX = 0
    let currentY = 0
    let startX = 0
    let startY = 0

    ctx.beginPath()

    commands.forEach((cmd, index) => {
      try {
        const type = cmd[0]
        const coords = cmd.slice(1).trim().split(/[\s,]+/).map(parseFloat).filter(n => !isNaN(n))

        switch (type) {
          case 'M':
            if (coords.length >= 2) {
              currentX = coords[0]
              currentY = coords[1]
              startX = currentX
              startY = currentY
              ctx.moveTo(currentX, currentY)
            }
            break
          case 'm':
            if (coords.length >= 2) {
              currentX += coords[0]
              currentY += coords[1]
              startX = currentX
              startY = currentY
              ctx.moveTo(currentX, currentY)
            }
            break
          case 'L':
            if (coords.length >= 2) {
              currentX = coords[0]
              currentY = coords[1]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'l':
            if (coords.length >= 2) {
              currentX += coords[0]
              currentY += coords[1]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'H':
            if (coords.length >= 1) {
              currentX = coords[0]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'h':
            if (coords.length >= 1) {
              currentX += coords[0]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'V':
            if (coords.length >= 1) {
              currentY = coords[0]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'v':
            if (coords.length >= 1) {
              currentY += coords[0]
              ctx.lineTo(currentX, currentY)
            }
            break
          case 'C':
            if (coords.length >= 6) {
              ctx.bezierCurveTo(coords[0], coords[1], coords[2], coords[3], coords[4], coords[5])
              currentX = coords[4]
              currentY = coords[5]
            }
            break
          case 'c':
            if (coords.length >= 6) {
              ctx.bezierCurveTo(
                currentX + coords[0], currentY + coords[1],
                currentX + coords[2], currentY + coords[3],
                currentX + coords[4], currentY + coords[5]
              )
              currentX += coords[4]
              currentY += coords[5]
            }
            break
          case 'Q':
            if (coords.length >= 4) {
              ctx.quadraticCurveTo(coords[0], coords[1], coords[2], coords[3])
              currentX = coords[2]
              currentY = coords[3]
            }
            break
          case 'q':
            if (coords.length >= 4) {
              ctx.quadraticCurveTo(
                currentX + coords[0], currentY + coords[1],
                currentX + coords[2], currentY + coords[3]
              )
              currentX += coords[2]
              currentY += coords[3]
            }
            break
          case 'Z':
          case 'z':
            ctx.closePath()
            currentX = startX
            currentY = startY
            break
        }
      } catch (cmdError) {
        console.warn(`Error processing SVG command ${index} (${cmd}):`, cmdError)
      }
    })

    ctx.fill()
    ctx.stroke()
  }

  createGlyphOverlay() {
    const overlayHTML = `
      <div id="glyph-details-overlay" class="tw-fixed tw-inset-0 tw-bg-black tw-bg-opacity-50 tw-z-50 tw-hidden tw-items-center tw-justify-center" style="display: none;">
        <div class="tw-bg-white tw-rounded-lg tw-shadow-xl tw-max-w-4xl tw-w-full tw-mx-4 tw-max-h-[90vh] tw-overflow-y-auto" onclick="event.stopPropagation()">
          <div class="tw-sticky tw-top-0 tw-bg-white tw-border-b tw-border-gray-200 tw-px-6 tw-py-4 tw-flex tw-justify-between tw-items-center tw-z-10">
            <h3 class="tw-text-xl tw-font-semibold tw-text-gray-900">Glyph Details</h3>
            <button id="close-glyph-overlay-btn" class="tw-text-gray-400 hover:tw-text-gray-600 tw-transition-colors">
              <svg class="tw-w-6 tw-h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
          <div class="tw-p-6">
            <div class="tw-grid tw-grid-cols-1 md:tw-grid-cols-2 tw-gap-6">
              <div>
                <div class="tw-mb-6">
                  <div class="tw-text-7xl tw-text-center tw-mb-3 tw-leading-none" id="glyph-char" style="font-family: '${this.fontFaceValue}'"></div>
                  <div class="tw-text-center tw-text-gray-600 tw-font-mono tw-text-lg" id="glyph-unicode"></div>
                </div>
                <div id="glyph-metadata" class="tw-text-sm tw-bg-gray-50 tw-rounded-lg tw-p-4"></div>
              </div>
              <div>
                <div class="tw-text-sm tw-font-semibold tw-mb-3 tw-text-gray-700">Glyph Outline</div>
                <div class="tw-border tw-border-gray-300 tw-rounded-lg tw-p-4 tw-bg-gray-50 tw-flex tw-items-center tw-justify-center">
                  <canvas id="glyph-outline-canvas" width="400" height="400" style="max-width: 100%; height: auto; display: block;"></canvas>
                </div>
              </div>
            </div>
          </div>
          <div class="tw-sticky tw-bottom-0 tw-bg-white tw-border-t tw-border-gray-200 tw-px-6 tw-py-4 tw-flex tw-justify-end">
            <button id="close-glyph-overlay-btn-bottom" class="tw-px-4 tw-py-2 tw-bg-gray-200 hover:tw-bg-gray-300 tw-text-gray-800 tw-rounded tw-transition-colors">
              Close
            </button>
          </div>
        </div>
      </div>
    `
    const overlay = document.createElement('div')
    overlay.innerHTML = overlayHTML
    const overlayEl = overlay.firstElementChild
    
    const closeButtons = overlayEl.querySelectorAll('#close-glyph-overlay-btn, #close-glyph-overlay-btn-bottom')
    closeButtons.forEach(btn => {
      btn.addEventListener('click', () => this.closeGlyphOverlay())
    })
    
    overlayEl.addEventListener('click', (e) => {
      if (e.target.id === 'glyph-details-overlay') {
        this.closeGlyphOverlay()
      }
    })
    
    document.body.appendChild(overlayEl)
    return overlayEl
  }

  showPlaceholderMessage() {
    try {
      const format = this.fontFormatValue || 'font'
      const placeholderHTML = `<div class="tw-flex tw-items-center tw-justify-center tw-min-h-[400px] tw-w-full"><div class="tw-text-center tw-p-8 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300 tw-max-w-md tw-mx-auto"><div class="tw-text-lg tw-font-medium tw-mb-2 tw-px-2">Preview is not available for this font</div><div class="tw-text-sm tw-mb-4">The ${format.toUpperCase()} font file could not be loaded</div>`
      
      if (this.hasGlyphsContainerTarget) {
        this.glyphsContainerTarget.innerHTML = placeholderHTML
        this.removeGridClasses()
      }
      
      if (this.hasSampleTextTarget) {
        this.sampleTextTarget.innerHTML = '<div class="tw-text-center tw-p-4 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300"><div class="tw-text-sm">Preview is not available for this font</div></div>'
      }
      
      if (this.hasLigaturesTableTarget) {
        this.ligaturesTableTarget.innerHTML = `<tr><td colspan="4" class="tw-text-center tw-p-8 tw-text-gray-500 tw-bg-gray-100 tw-rounded tw-border-2 tw-border-dashed tw-border-gray-300"><div class="tw-text-lg tw-font-medium tw-mb-2">Preview is not available for this font</div><div class="tw-text-sm">The ${format.toUpperCase()} font file could not be loaded</div></td></tr>`
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

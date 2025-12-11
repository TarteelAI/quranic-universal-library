import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    pageNumber: Number,
    updateUrl: String
  }

  connect() {
    this.updateTimeouts = {}
    this.setupInputListeners()
    this.setupPreviewWordLinks()
  }

  setupPreviewWordLinks() {
    const preview = document.getElementById('preview')
    if (!preview) return

    const observer = new MutationObserver(() => {
      this.attachPreviewWordClickHandlers()
    })
    
    observer.observe(preview, { childList: true, subtree: true })
    this.attachPreviewWordClickHandlers()
  }

  attachPreviewWordClickHandlers() {
    const preview = document.getElementById('preview')
    if (!preview) return

    preview.querySelectorAll('.preview-word-link').forEach(link => {
      if (!link.dataset.clickHandlerAttached) {
        link.addEventListener('click', (e) => {
          e.preventDefault()
          const wordId = link.dataset.wordId
          this.scrollToWordForm(wordId)
        })
        link.dataset.clickHandlerAttached = 'true'
      }
    })
  }

  scrollToWordForm(wordId) {
    const formContainer = document.getElementById(`word-form-${wordId}`)
    
    if (formContainer) {
      formContainer.scrollIntoView({ behavior: 'smooth', block: 'center' })
      
      formContainer.style.transition = 'background-color 0.3s ease'
      formContainer.style.backgroundColor = '#fef3c7'
      
      setTimeout(() => {
        formContainer.style.backgroundColor = ''
        setTimeout(() => {
          formContainer.style.transition = ''
        }, 300)
      }, 1500)
    }
  }

  setupInputListeners() {
    const observer = new MutationObserver(() => {
      this.attachListenersToNewInputs()
    })
    
    observer.observe(this.element, { childList: true, subtree: true })
    this.attachListenersToNewInputs()
  }

  attachListenersToNewInputs() {
    this.element.querySelectorAll('input[type="number"][name*="[mistake_count]"]').forEach(input => {
      if (!input.dataset.listenerAttached || input.dataset.listenerAttached !== 'true') {
        input.addEventListener('input', (e) => {
          this.handleInputChange(e.target)
        })
        input.dataset.listenerAttached = 'true'
      }
    })
  }

  handleInputChange(input) {
    const mistakeKey = this.extractMistakeKey(input.name)
    if (!mistakeKey) return

    clearTimeout(this.updateTimeouts[mistakeKey])
    
    this.updateTimeouts[mistakeKey] = setTimeout(() => {
      this.saveMistake(input, mistakeKey)
    }, 500)
  }

  extractMistakeKey(name) {
    const match = name.match(/mistakes\[([^\]]+)\]/)
    return match ? match[1] : null
  }

  async saveMistake(input, mistakeKey) {
    const mistakeCount = parseInt(input.value) || 0
    const [wordId, charStart, charEnd] = this.parseMistakeKey(mistakeKey)
    
    const data = {
      mistakes: {
        [mistakeKey]: {
          mistake_count: mistakeCount,
          char_start: charStart === 'nil' ? null : charStart,
          char_end: charEnd === 'nil' ? null : charEnd
        }
      }
    }

    try {
      const response = await fetch(this.updateUrlValue, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify(data)
      })

      if (response.ok) {
        this.updatePreview(wordId, charStart, charEnd, mistakeCount)
        this.showSaveIndicator(input)
      } else {
        console.error('Failed to save mistake')
      }
    } catch (error) {
      console.error('Error saving mistake:', error)
    }
  }

  parseMistakeKey(key) {
    const parts = key.split('_')
    let wordId = parts[0]
    let charStart = parts[1] === 'nil' ? null : parseInt(parts[1])
    let charEnd = parts[2] === 'nil' ? null : parseInt(parts[2])
    
    if (charStart !== null && charEnd !== null && charStart > charEnd) {
      [charStart, charEnd] = [charEnd, charStart]
    }
    
    return [wordId, charStart, charEnd]
  }

  updatePreview(wordId, charStart, charEnd, mistakeCount) {
    const wordIdStr = wordId.toString()
    const charStartStr = charStart === 'nil' ? null : charStart
    const charEndStr = charEnd === 'nil' ? null : charEnd

    const preview = document.getElementById('preview')
    if (!preview) return
    
    const wordElement = preview.querySelector(`[data-word-id="${wordIdStr}"]`)
    if (!wordElement) return

    if (charStartStr === null && charEndStr === null) {
      this.updateFullWordPreview(wordElement, mistakeCount)
    } else {
      this.updatePartialWordPreview(wordElement, parseInt(charStartStr), parseInt(charEndStr), mistakeCount)
    }
  }

  updateFullWordPreview(wordElement, mistakeCount) {
    if (mistakeCount > 0) {
      const textColor = this.mistakeColor(mistakeCount)
      const glow = this.mistakeGlowIntensity(mistakeCount)
      
      wordElement.classList.add('word-mistake-highlight')
      wordElement.style.color = textColor
      wordElement.style.textShadow = `0 0 ${glow}px ${textColor}`
      wordElement.title = `Mistakes: ${mistakeCount}`
    } else {
      wordElement.classList.remove('word-mistake-highlight')
      wordElement.style.color = ''
      wordElement.style.textShadow = ''
      wordElement.title = ''
    }
  }

  updatePartialWordPreview(wordElement, charStart, charEnd, mistakeCount) {
    const textNode = wordElement.querySelector('a')
    if (!textNode) return

    let originalText = wordElement.dataset.originalText
    if (!originalText) {
      originalText = textNode.textContent || textNode.innerText || ''
      wordElement.dataset.originalText = originalText
    }
    
    const wordText = originalText
    
    const existingPartialHighlights = wordElement.querySelectorAll('.word-mistake-highlight-partial')
    const highlightMap = new Map()
    
    existingPartialHighlights.forEach(span => {
      const start = parseInt(span.dataset.charStart || span.getAttribute('data-char-start'))
      const end = parseInt(span.dataset.charEnd || span.getAttribute('data-char-end'))
      if (!isNaN(start) && !isNaN(end) && !(start === charStart && end === charEnd)) {
        const count = parseInt(span.dataset.mistakeCount || span.getAttribute('data-mistake-count')) || 0
        if (count > 0) {
          highlightMap.set(`${start}-${end}`, {
            start,
            end,
            count
          })
        }
      }
    })
    
    if (mistakeCount > 0) {
      highlightMap.set(`${charStart}-${charEnd}`, {
        start: charStart,
        end: charEnd,
        count: mistakeCount
      })
    }
    
    const sortedHighlights = Array.from(highlightMap.values()).sort((a, b) => a.start - b.start)
    
    let html = ''
    let lastPos = 0
    
    sortedHighlights.forEach(highlight => {
      if (lastPos < highlight.start) {
        const plainText = wordText.substring(lastPos, highlight.start)
        html += plainText
      }
      
      const textColor = this.mistakeColor(highlight.count)
      const glow = this.mistakeGlowIntensity(highlight.count)
      const highlightText = wordText.substring(highlight.start, highlight.end)
      
      html += `<span class="word-mistake-highlight-partial" data-char-start="${highlight.start}" data-char-end="${highlight.end}" data-mistake-count="${highlight.count}" style="color: ${textColor}; text-shadow: 0 0 ${glow}px ${textColor};" title="Mistakes: ${highlight.count}">${highlightText}</span>`
      lastPos = highlight.end
    })
    
    if (lastPos < wordText.length) {
      html += wordText.substring(lastPos)
    }
    
    textNode.innerHTML = html || wordText
  }

  mistakeColor(mistakeCount, maxMistakes = 50) {
    if (!mistakeCount || mistakeCount === 0) return 'inherit'
    
    const normalized = Math.min(mistakeCount / maxMistakes, 1.0)
    const r = Math.round(255 * normalized)
    const g = Math.round(255 * (1 - normalized))
    const b = 0
    return `rgb(${r}, ${g}, ${b})`
  }

  mistakeGlowIntensity(mistakeCount, maxMistakes = 50) {
    if (!mistakeCount || mistakeCount === 0) return 0
    const normalized = Math.min(mistakeCount / maxMistakes, 1.0)
    return Math.round(normalized * 20)
  }

  showSaveIndicator(input) {
    const originalBg = input.style.backgroundColor
    input.style.backgroundColor = '#d4edda'
    
    setTimeout(() => {
      input.style.backgroundColor = originalBg
    }, 300)
  }

  removePartialRange(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const container = button.closest('[data-partial-range]')
    const mistakeKey = this.extractMistakeKeyFromContainer(container)
    
    if (mistakeKey) {
      const [wordId, charStart, charEnd] = this.parseMistakeKey(mistakeKey)
      
      fetch(this.updateUrlValue, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          mistakes: {
            [mistakeKey]: {
              mistake_count: 0,
              char_start: charStart === 'nil' ? null : charStart,
              char_end: charEnd === 'nil' ? null : charEnd
            }
          }
        })
      }).then(response => {
        if (response.ok) {
          container.remove()
          this.updatePreview(wordId, charStart, charEnd, 0)
        }
      }).catch(error => {
        console.error('Error removing partial range:', error)
      })
    } else {
      container.remove()
    }
  }

  extractMistakeKeyFromContainer(container) {
    const input = container.querySelector('input[type="number"][name*="[mistake_count]"]')
    return input ? this.extractMistakeKey(input.name) : null
  }
}

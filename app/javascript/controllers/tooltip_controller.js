import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = { 
    placement: { type: String, default: "top" },
    title: String,
    html: { type: Boolean, default: false }
  }

  connect() {
    this.tooltip = null
    this.boundMouseEnter = this.show.bind(this)
    this.boundMouseLeave = this.hide.bind(this)
    this.boundFocus = this.show.bind(this)
    this.boundBlur = this.hide.bind(this)
    
    // Add event listeners
    this.element.addEventListener('mouseenter', this.boundMouseEnter)
    this.element.addEventListener('mouseleave', this.boundMouseLeave)
    this.element.addEventListener('focus', this.boundFocus)
    this.element.addEventListener('blur', this.boundBlur)
  }

  disconnect() {
    this.hide()
    this.element.removeEventListener('mouseenter', this.boundMouseEnter)
    this.element.removeEventListener('mouseleave', this.boundMouseLeave)
    this.element.removeEventListener('focus', this.boundFocus)
    this.element.removeEventListener('blur', this.boundBlur)
  }

  show() {
    if (this.tooltip) return
    
    const title = this.titleValue || this.element.getAttribute('title') || this.element.dataset.bsOriginalTitle
    if (!title) return
    
    // Remove title attribute to prevent browser tooltip
    this.element.setAttribute('data-bs-original-title', title)
    this.element.removeAttribute('title')
    
    this.tooltip = this.createTooltip(title)
    this.positionTooltip()
    
    // Show tooltip
    setTimeout(() => {
      if (this.tooltip) {
        this.tooltip.classList.add('show')
      }
    }, 100)
  }

  hide() {
    if (!this.tooltip) return
    
    this.tooltip.remove()
    this.tooltip = null
    
    // Restore title attribute
    const originalTitle = this.element.getAttribute('data-bs-original-title')
    if (originalTitle) {
      this.element.setAttribute('title', originalTitle)
      this.element.removeAttribute('data-bs-original-title')
    }
  }

  createTooltip(content) {
    const tooltip = document.createElement('div')
    tooltip.className = `tooltip bs-tooltip-${this.placementValue}`
    tooltip.setAttribute('role', 'tooltip')
    
    const arrow = document.createElement('div')
    arrow.className = 'tooltip-arrow'
    
    const inner = document.createElement('div')
    inner.className = 'tooltip-inner'
    
    if (this.htmlValue) {
      inner.innerHTML = content
    } else {
      inner.textContent = content
    }
    
    tooltip.appendChild(arrow)
    tooltip.appendChild(inner)
    document.body.appendChild(tooltip)
    
    return tooltip
  }

  positionTooltip() {
    if (!this.tooltip) return
    
    const elementRect = this.element.getBoundingClientRect()
    const tooltipRect = this.tooltip.getBoundingClientRect()
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft
    
    let top, left
    
    switch (this.placementValue) {
      case 'top':
        top = elementRect.top + scrollTop - tooltipRect.height - 8
        left = elementRect.left + scrollLeft + (elementRect.width - tooltipRect.width) / 2
        break
      case 'bottom':
        top = elementRect.bottom + scrollTop + 8
        left = elementRect.left + scrollLeft + (elementRect.width - tooltipRect.width) / 2
        break
      case 'left':
        top = elementRect.top + scrollTop + (elementRect.height - tooltipRect.height) / 2
        left = elementRect.left + scrollLeft - tooltipRect.width - 8
        break
      case 'right':
        top = elementRect.top + scrollTop + (elementRect.height - tooltipRect.height) / 2
        left = elementRect.right + scrollLeft + 8
        break
      default:
        top = elementRect.top + scrollTop - tooltipRect.height - 8
        left = elementRect.left + scrollLeft + (elementRect.width - tooltipRect.width) / 2
    }
    
    // Keep tooltip within viewport
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    
    if (left < 8) left = 8
    if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8
    }
    
    if (top < 8) top = 8
    if (top + tooltipRect.height > viewportHeight - 8) {
      top = viewportHeight - tooltipRect.height - 8
    }
    
    this.tooltip.style.top = top + 'px'
    this.tooltip.style.left = left + 'px'
  }
}

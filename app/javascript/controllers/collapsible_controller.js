import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    // All collapsibles start closed with inline styles
  }

  toggle(event) {
    event.preventDefault()
    const trigger = event.currentTarget
    const targetId = trigger.dataset.target
    const content = document.getElementById(targetId)
    const iconContainer = trigger.querySelector('[data-collapsible-target="icon"]')
    
    if (content) {
      const isVisible = content.style.display !== 'none'
      
      if (isVisible) {
        // Collapse
        content.style.display = 'none'
        this.updateIconElement(iconContainer, false)
      } else {
        // Expand
        content.style.display = 'block'
        this.updateIconElement(iconContainer, true)
      }
    }
  }

  updateIconElement(iconContainer, isExpanded) {
    if (!iconContainer) return
    
    const revealSpan = iconContainer.querySelector('.collapsed-reveal')
    const hiddenSpan = iconContainer.querySelector('.collapsed-hidden')
    
    if (isExpanded) {
      revealSpan.style.display = 'none'
      hiddenSpan.style.display = 'inline'
    } else {
      revealSpan.style.display = 'inline'
      hiddenSpan.style.display = 'none'
    }
  }
}

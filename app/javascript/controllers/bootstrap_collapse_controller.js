import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bootstrap-collapse"
export default class extends Controller {
  static targets = ["content"]
  static values = { 
    toggle: String,
    target: String,
    parent: String
  }

  connect() {
    // Handle both new Stimulus attributes and legacy Bootstrap attributes
    this.toggleValue = this.element.dataset.bsToggle || this.element.dataset.toggle || "collapse"
    this.targetValue = this.element.dataset.bsTarget || this.element.dataset.target || "#" + this.element.id + "Collapse"
    this.parentValue = this.element.dataset.bsParent || this.element.dataset.parent
    
    // Set initial ARIA attributes
    this.updateAriaAttributes()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const content = this.getContent()
    if (!content) return
    
    const isOpen = content.classList.contains('show')
    
    if (this.parentValue) {
      // Accordion behavior - close other items in parent
      this.closeOtherItems()
    }
    
    if (!isOpen) {
      this.openCollapse(content)
    } else {
      this.closeCollapse(content)
    }
  }

  openCollapse(content) {
    // Add transition classes
    content.style.height = '0px'
    content.style.overflow = 'hidden'
    content.style.transition = 'height 0.35s ease'
    
    // Force reflow
    content.offsetHeight
    
    // Set to auto height
    content.style.height = content.scrollHeight + 'px'
    
    // Add show class after a brief delay
    setTimeout(() => {
      content.classList.add('show')
      this.element.setAttribute('aria-expanded', 'true')
      
      // Clean up inline styles
      content.style.height = ''
      content.style.overflow = ''
      content.style.transition = ''
      
      // Trigger custom event
      this.dispatch('opened', { detail: { content } })
    }, 10)
  }

  closeCollapse(content) {
    // Store current height
    content.style.height = content.scrollHeight + 'px'
    content.style.overflow = 'hidden'
    content.style.transition = 'height 0.35s ease'
    
    // Force reflow
    content.offsetHeight
    
    // Collapse to 0
    content.style.height = '0px'
    
    // Remove show class and clean up
    setTimeout(() => {
      content.classList.remove('show')
      this.element.setAttribute('aria-expanded', 'false')
      
      // Clean up inline styles
      content.style.height = ''
      content.style.overflow = ''
      content.style.transition = ''
      
      // Trigger custom event
      this.dispatch('closed', { detail: { content } })
    }, 350)
  }

  closeOtherItems() {
    if (!this.parentValue) return
    
    const parent = document.querySelector(this.parentValue)
    if (!parent) return
    
    const otherTriggers = parent.querySelectorAll(`[data-controller*="bootstrap-collapse"]:not([data-controller*="${this.identifier}"])`)
    otherTriggers.forEach(trigger => {
      const controller = this.application.getControllerForElementAndIdentifier(trigger, 'bootstrap-collapse')
      if (controller) {
        const content = controller.getContent()
        if (content && content.classList.contains('show')) {
          controller.closeCollapse(content)
        }
      }
    })
  }

  getContent() {
    if (this.hasContentTarget) {
      return this.contentTarget
    }
    
    const target = this.targetValue.startsWith('#') 
      ? document.querySelector(this.targetValue)
      : document.querySelector(`#${this.targetValue}`)
    
    return target
  }

  updateAriaAttributes() {
    const content = this.getContent()
    if (!content) return
    
    const isOpen = content.classList.contains('show')
    this.element.setAttribute('aria-expanded', isOpen.toString())
    
    // Ensure content has proper ID and aria-labelledby
    if (!content.id) {
      content.id = this.targetValue.replace('#', '')
    }
    
    this.element.setAttribute('aria-controls', content.id)
  }

  // Method to programmatically open/close
  show() {
    const content = this.getContent()
    if (content && !content.classList.contains('show')) {
      this.openCollapse(content)
    }
  }

  hide() {
    const content = this.getContent()
    if (content && content.classList.contains('show')) {
      this.closeCollapse(content)
    }
  }
}

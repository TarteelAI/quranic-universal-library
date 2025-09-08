import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bootstrap-modal"
export default class extends Controller {
  static targets = ["modal", "backdrop"]
  static values = { 
    toggle: String,
    target: String,
    backdrop: { type: String, default: "true" },
    keyboard: { type: Boolean, default: true }
  }

  connect() {
    // Handle both new Stimulus attributes and legacy Bootstrap attributes
    this.toggleValue = this.element.dataset.bsToggle || this.element.dataset.toggle || "modal"
    this.targetValue = this.element.dataset.bsTarget || this.element.dataset.target || "#" + this.element.id + "Modal"
    this.backdropValue = this.element.dataset.bsBackdrop || this.element.dataset.backdrop || "true"
    this.keyboardValue = this.element.dataset.bsKeyboard !== "false" && this.element.dataset.keyboard !== "false"
    
    // Handle escape key
    if (this.keyboardValue) {
      this.boundKeydown = this.handleKeydown.bind(this)
      document.addEventListener('keydown', this.boundKeydown)
    }
  }

  disconnect() {
    if (this.boundKeydown) {
      document.removeEventListener('keydown', this.boundKeydown)
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const modal = this.getModal()
    if (!modal) return
    
    const isOpen = modal.classList.contains('show')
    
    if (!isOpen) {
      this.openModal(modal)
    } else {
      this.closeModal(modal)
    }
  }

  openModal(modal) {
    // Close any other open modals
    this.closeAllModals()
    
    modal.classList.add('show')
    modal.style.display = 'block'
    
    // Add backdrop
    if (this.backdropValue === "true") {
      this.createBackdrop()
    }
    
    // Prevent body scroll
    document.body.classList.add('modal-open')
    
    // Focus management
    this.trapFocus(modal)
    
    // Trigger custom event
    this.dispatch('opened', { detail: { modal } })
  }

  closeModal(modal) {
    modal.classList.remove('show')
    modal.style.display = 'none'
    
    // Remove backdrop
    this.removeBackdrop()
    
    // Restore body scroll
    document.body.classList.remove('modal-open')
    
    // Return focus to trigger
    this.element.focus()
    
    // Trigger custom event
    this.dispatch('closed', { detail: { modal } })
  }

  closeAllModals() {
    const allModals = document.querySelectorAll('.modal.show')
    allModals.forEach(modal => {
      modal.classList.remove('show')
      modal.style.display = 'none'
    })
    
    this.removeBackdrop()
    document.body.classList.remove('modal-open')
  }

  getModal() {
    if (this.hasModalTarget) {
      return this.modalTarget
    }
    
    const target = this.targetValue.startsWith('#') 
      ? document.querySelector(this.targetValue)
      : document.querySelector(`#${this.targetValue}`)
    
    return target
  }

  createBackdrop() {
    if (document.querySelector('.modal-backdrop')) return
    
    const backdrop = document.createElement('div')
    backdrop.className = 'modal-backdrop'
    backdrop.setAttribute('data-controller', 'bootstrap-modal')
    backdrop.setAttribute('data-action', 'click->bootstrap-modal#closeOnBackdrop')
    
    document.body.appendChild(backdrop)
    
    // Trigger backdrop click to close modal
    backdrop.addEventListener('click', () => {
      const modal = this.getModal()
      if (modal && this.backdropValue === "true") {
        this.closeModal(modal)
      }
    })
  }

  removeBackdrop() {
    const backdrop = document.querySelector('.modal-backdrop')
    if (backdrop) {
      backdrop.remove()
    }
  }

  closeOnBackdrop(event) {
    if (event.target.classList.contains('modal-backdrop')) {
      const modal = this.getModal()
      if (modal) {
        this.closeModal(modal)
      }
    }
  }

  trapFocus(modal) {
    const focusableElements = modal.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    if (focusableElements.length === 0) return
    
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]
    
    modal.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            lastElement.focus()
            e.preventDefault()
          }
        } else {
          if (document.activeElement === lastElement) {
            firstElement.focus()
            e.preventDefault()
          }
        }
      }
    })
    
    firstElement.focus()
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      const modal = this.getModal()
      if (modal && modal.classList.contains('show')) {
        this.closeModal(modal)
      }
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bootstrap-dropdown"
export default class extends Controller {
  static targets = ["menu"]
  static values = { 
    toggle: String,
    target: String 
  }

  connect() {
    // Handle both new Stimulus attributes and legacy Bootstrap attributes
    this.toggleValue = this.element.dataset.bsToggle || this.element.dataset.toggle || "dropdown"
    this.targetValue = this.element.dataset.bsTarget || this.element.dataset.target || "#" + this.element.id + "Menu"
    
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener('click', this.boundClickOutside)
    
    // Close dropdown on escape key
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClickOutside)
    document.removeEventListener('keydown', this.boundKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const menu = this.getMenu()
    if (!menu) return
    
    const isOpen = menu.classList.contains('show')
    
    // Close all other dropdowns
    this.closeAllDropdowns()
    
    if (!isOpen) {
      this.openDropdown(menu)
    }
  }

  openDropdown(menu) {
    menu.classList.add('show')
    this.element.setAttribute('aria-expanded', 'true')
    
    // Position the dropdown
    this.positionDropdown(menu)
  }

  closeDropdown(menu) {
    menu.classList.remove('show')
    this.element.setAttribute('aria-expanded', 'false')
  }

  closeAllDropdowns() {
    const allMenus = document.querySelectorAll('.dropdown-menu.show')
    allMenus.forEach(menu => {
      menu.classList.remove('show')
      const trigger = document.querySelector(`[aria-expanded="true"]`)
      if (trigger) {
        trigger.setAttribute('aria-expanded', 'false')
      }
    })
  }

  getMenu() {
    if (this.hasMenuTarget) {
      return this.menuTarget
    }
    
    const target = this.targetValue.startsWith('#') 
      ? document.querySelector(this.targetValue)
      : document.querySelector(`#${this.targetValue}`)
    
    return target
  }

  positionDropdown(menu) {
    const rect = this.element.getBoundingClientRect()
    const menuRect = menu.getBoundingClientRect()
    
    // Check if there's enough space below
    const spaceBelow = window.innerHeight - rect.bottom
    const spaceAbove = rect.top
    
    if (spaceBelow < menuRect.height && spaceAbove > menuRect.height) {
      // Position above
      menu.style.top = 'auto'
      menu.style.bottom = '100%'
      menu.style.marginBottom = '2px'
    } else {
      // Position below (default)
      menu.style.top = '100%'
      menu.style.bottom = 'auto'
      menu.style.marginTop = '2px'
    }
  }

  clickOutside(event) {
    const menu = this.getMenu()
    if (!menu || !menu.classList.contains('show')) return
    
    if (!this.element.contains(event.target) && !menu.contains(event.target)) {
      this.closeDropdown(menu)
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      const menu = this.getMenu()
      if (menu && menu.classList.contains('show')) {
        this.closeDropdown(menu)
        this.element.focus()
      }
    }
  }
}

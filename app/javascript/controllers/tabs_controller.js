import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const tabButtons = this.element.querySelectorAll('[data-bs-toggle="tab"]')
    
    const updateBorders = (activeButton) => {
      tabButtons.forEach(btn => {
        btn.style.borderTop = 'none'
        btn.style.borderRight = 'none'
        btn.style.borderLeft = 'none'
        btn.style.borderBottom = 'none'
      })
      
      if (activeButton) {
        activeButton.style.borderTop = '1px solid #dee2e6'
        activeButton.style.borderRight = '1px solid #dee2e6'
        activeButton.style.borderLeft = '1px solid #dee2e6'
        activeButton.style.borderBottom = 'none'
      }
    }
    
    const initialActive = this.element.querySelector('[data-bs-toggle="tab"].active')
    if (initialActive) {
      updateBorders(initialActive)
    }
    
    tabButtons.forEach(button => {
      button.addEventListener('click', function(e) {
        e.preventDefault()
        e.stopPropagation()
        
        tabButtons.forEach(btn => btn.classList.remove('active'))
        
        this.classList.add('active')
        
        updateBorders(this)
        
        const targetId = this.getAttribute('data-bs-target')
        if (targetId) {
          const allPanes = document.querySelectorAll('.tab-pane')
          allPanes.forEach(pane => {
            pane.classList.remove('show', 'active')
          })
          
          const targetPane = document.querySelector(targetId)
          if (targetPane) {
            targetPane.classList.add('show', 'active')
          }
        }
      })
    })
  }
}


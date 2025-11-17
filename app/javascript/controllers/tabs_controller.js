import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const tabButtons = this.element.querySelectorAll('[data-bs-toggle="tab"]')
    
    tabButtons.forEach(btn => {
      btn.classList.add('tw-rounded-t')
    })
    
    const updateBordersAndColors = (activeButton) => {
      tabButtons.forEach(btn => {
        // Remove borders from all buttons
        btn.style.borderTop = 'none'
        btn.style.borderRight = 'none'
        btn.style.borderLeft = 'none'
        btn.style.borderBottom = 'none'
        
        // Set inactive color for all buttons
        btn.classList.remove('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white')
        btn.classList.add('tw-text-[#57d798]')
      })
      
      if (activeButton) {
        // Add borders to active button
        activeButton.style.borderTop = '1px solid #dee2e6'
        activeButton.style.borderRight = '1px solid #dee2e6'
        activeButton.style.borderLeft = '1px solid #dee2e6'
        activeButton.style.borderBottom = 'none'
        
        // Set active color and styling
        activeButton.classList.remove('tw-text-[#57d798]')
        activeButton.classList.add('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white')
      }
    }
    
    const initialActive = this.element.querySelector('[data-bs-toggle="tab"].active')
    if (initialActive) {
      updateBordersAndColors(initialActive)
    }
    
    tabButtons.forEach(button => {
      button.addEventListener('click', function(e) {
        e.preventDefault()
        e.stopPropagation()
        
        tabButtons.forEach(btn => btn.classList.remove('active'))
        
        this.classList.add('active')
        
        updateBordersAndColors(this)
        
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


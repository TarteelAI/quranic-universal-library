import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const tabButtons = this.element.querySelectorAll('[data-bs-toggle="tab"]')
    const controller = this
    
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
      const targetId = initialActive.getAttribute('data-bs-target')
      if (targetId) this.updateAyahNavLinks(targetId.replace('#', ''))
    }
    
    tabButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        
        tabButtons.forEach(btn => btn.classList.remove('active'))
        
        button.classList.add('active')
        
        updateBordersAndColors(button)
        
        const targetId = button.getAttribute('data-bs-target')
        if (targetId) {
          const allPanes = document.querySelectorAll('.tab-pane')
          allPanes.forEach(pane => {
            pane.classList.remove('show', 'active')
          })
          
          const targetPane = document.querySelector(targetId)
          if (targetPane) {
            targetPane.classList.add('show', 'active')
          }
          controller.updateAyahNavLinks(targetId.replace('#', ''))
        }
      })
    })
  }

  updateAyahNavLinks(tabKey) {
    const header = document.getElementById('modal-header')
    if (!header) return
    const links = header.querySelectorAll('a[data-ayah-nav="true"]')
    links.forEach((a) => {
      try {
        const url = new URL(a.getAttribute('href'), window.location.origin)
        url.searchParams.set('tab', tabKey)
        a.setAttribute('href', url.pathname + url.search)
      } catch (_) {
      }
    })

    const jump = header.querySelector('[data-ayah-jump-tab-value]')
    if (jump) {
      jump.setAttribute('data-ayah-jump-tab-value', tabKey)
    }
  }
}


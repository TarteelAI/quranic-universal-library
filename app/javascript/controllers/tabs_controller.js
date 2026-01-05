import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pane"]
  static values = {
    activeTab: String
  }

  connect() {
    const tabButtons = this.element.querySelectorAll('[data-tabs-target-value], [data-bs-toggle="tab"]')
    const controller = this
    
    tabButtons.forEach(btn => {
      btn.classList.add('tw-rounded-t')
      if (!btn.hasAttribute('data-action')) {
        btn.setAttribute('data-action', 'click->tabs#switch')
      }
    })
    
    const updateBordersAndColors = (activeButton) => {
      tabButtons.forEach(btn => {
        btn.style.borderTop = 'none'
        btn.style.borderRight = 'none'
        btn.style.borderLeft = 'none'
        btn.style.borderBottom = 'none'
        
        btn.classList.remove('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white', 'active')
        btn.classList.add('tw-text-[#57d798]')
      })
      
      if (activeButton) {
        activeButton.style.borderTop = '1px solid #dee2e6'
        activeButton.style.borderRight = '1px solid #dee2e6'
        activeButton.style.borderLeft = '1px solid #dee2e6'
        activeButton.style.borderBottom = 'none'
        
        activeButton.classList.remove('tw-text-[#57d798]')
        activeButton.classList.add('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white', 'active')
      }
    }
    
    const initialActive = this.element.querySelector('[data-bs-toggle="tab"].active, [data-tabs-target-value].active')
    if (initialActive) {
      updateBordersAndColors(initialActive)
      const targetId = initialActive.getAttribute('data-bs-target') || initialActive.getAttribute('data-tabs-target-value')
      if (targetId) this.updateAyahNavLinks(targetId.replace('#', ''))
    }
  }

  switch(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const tabButtons = this.element.querySelectorAll('[data-tabs-target-value], [data-bs-toggle="tab"]')
    
    tabButtons.forEach(btn => btn.classList.remove('active'))
    button.classList.add('active')
    
    const updateBordersAndColors = (activeButton) => {
      tabButtons.forEach(btn => {
        btn.style.borderTop = 'none'
        btn.style.borderRight = 'none'
        btn.style.borderLeft = 'none'
        btn.style.borderBottom = 'none'
        
        btn.classList.remove('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white')
        btn.classList.add('tw-text-[#57d798]')
      })
      
      if (activeButton) {
        activeButton.style.borderTop = '1px solid #dee2e6'
        activeButton.style.borderRight = '1px solid #dee2e6'
        activeButton.style.borderLeft = '1px solid #dee2e6'
        activeButton.style.borderBottom = 'none'
        
        activeButton.classList.remove('tw-text-[#57d798]')
        activeButton.classList.add('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white')
      }
    }
    
    updateBordersAndColors(button)
    
    const targetId = button.getAttribute('data-bs-target') || button.getAttribute('data-tabs-target-value')
    if (targetId) {
      const allPanes = document.querySelectorAll('.tab-pane')
      allPanes.forEach(pane => {
        pane.classList.remove('show', 'active')
      })
      
      const targetPane = document.querySelector(targetId)
      if (targetPane) {
        targetPane.classList.add('show', 'active')
      }
      this.updateAyahNavLinks(targetId.replace('#', ''))
    }
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


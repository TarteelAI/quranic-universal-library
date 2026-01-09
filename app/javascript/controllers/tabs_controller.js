import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pane"]
  static values = {
    activeTab: String
  }

  connect() {
    const tabButtons = this.getTabButtons()
    
    tabButtons.forEach(btn => {
      btn.classList.add('tw-rounded-t')
      if (!btn.hasAttribute('data-action')) {
        btn.setAttribute('data-action', 'click->tabs#switch')
      }
    })
    
    let initialActive = this.element.querySelector('[data-tabs-target-value].active, [role="tab"].active, .active[data-action*="tabs#switch"]')
    if (!initialActive && tabButtons.length > 0) initialActive = tabButtons[0]
    if (initialActive) this.activateTab(initialActive, tabButtons)
  }

  getTabButtons() {
    return this.element.querySelectorAll('[data-tabs-target-value], [role="tab"], [data-action*="tabs#switch"]')
  }

  getTabPanes() {
    return this.element.querySelectorAll('[role="tabpanel"]')
  }

  switch(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const tabButtons = this.getTabButtons()
    
    this.activateTab(button, tabButtons)
  }

  activateTab(button, tabButtons) {
    this.updateBordersAndColors(button, tabButtons)
    const rawTarget = button.getAttribute('data-tabs-target-value')
    if (rawTarget) {
      const targetId = rawTarget.startsWith('#') ? rawTarget : `#${rawTarget}`
      this.showPane(targetId)
      this.updateAyahNavLinks(targetId.replace('#', ''))
    }
  }

  showPane(targetId) {
    const allPanes = this.getTabPanes()
    allPanes.forEach(pane => {
      pane.classList.remove('active')
      pane.classList.add('tw-hidden')
      pane.setAttribute('hidden', 'hidden')
    })

    const targetPane = this.element.querySelector(targetId)
    if (targetPane) {
      targetPane.classList.add('active')
      targetPane.classList.remove('tw-hidden')
      targetPane.removeAttribute('hidden')
    }
  }

  updateBordersAndColors(activeButton, tabButtons) {
    tabButtons.forEach(btn => {
      btn.style.borderTop = 'none'
      btn.style.borderRight = 'none'
      btn.style.borderLeft = 'none'
      btn.style.borderBottom = 'none'
      
      btn.classList.remove('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white', 'active')
      btn.classList.add('tw-text-[#57d798]')
      btn.setAttribute('aria-selected', 'false')
    })
    
    if (activeButton) {
      activeButton.style.borderTop = '1px solid #dee2e6'
      activeButton.style.borderRight = '1px solid #dee2e6'
      activeButton.style.borderLeft = '1px solid #dee2e6'
      activeButton.style.borderBottom = 'none'
      
      activeButton.classList.remove('tw-text-[#57d798]')
      activeButton.classList.add('tw-text-gray-700', 'tw-bg-white', 'tw--mb-px', 'tw-border-b', 'tw-border-b-white', 'active')
      activeButton.setAttribute('aria-selected', 'true')
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


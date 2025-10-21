import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "item"]
  
  connect() {
    this.showSelectedItem()
  }
  
  showSelectedItem() {
    const selectedId = this.selectTarget.value
    
    this.itemTargets.forEach(item => {
      if (item.dataset.itemId === selectedId) {
        item.classList.remove('tw-hidden')
      } else {
        item.classList.add('tw-hidden')
      }
    })
  }
  
  change() {
    this.showSelectedItem()
  }
}


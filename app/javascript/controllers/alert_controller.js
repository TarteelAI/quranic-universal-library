import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Find and attach click handler to close button
    const closeButton = this.element.querySelector('[data-bs-dismiss="alert"]');
    if (closeButton) {
      closeButton.addEventListener('click', () => {
        this.close();
      });
    }
  }

  close() {
    // Fade out the alert
    this.element.style.transition = 'opacity 0.15s linear';
    this.element.style.opacity = '0';
    
    // Remove the alert after fade out
    setTimeout(() => {
      this.element.remove();
    }, 150);
  }
}


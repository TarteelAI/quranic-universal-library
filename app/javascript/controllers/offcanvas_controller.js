import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["offcanvas"];

  connect() {
    // Initialize if this controller is on an offcanvas element
    if (this.element.classList.contains("offcanvas")) {
      this.offcanvasTarget = this.element;
    }

    // Create backdrop element for later use
    this.backdrop = null;
  }

  toggle(event) {
    if (event) event.preventDefault();

    const offcanvasElement = this.getOffcanvasElement(event);
    if (!offcanvasElement) return;

    if (offcanvasElement.classList.contains("show")) {
      this.hide();
    } else {
      this.show();
    }
  }

  show(event) {
    if (event) event.preventDefault();

    const offcanvasElement = this.getOffcanvasElement(event);
    if (!offcanvasElement) return;

    // Prevent body scroll
    document.body.style.overflow = "hidden";

    // Create backdrop
    this.createBackdrop();

    // Show offcanvas with animation
    offcanvasElement.style.visibility = "visible";
    offcanvasElement.classList.add("show");

    // Add event listeners
    this.addEventListeners(offcanvasElement);

    // Trigger custom event
    const showEvent = new CustomEvent("offcanvas:shown", {
      detail: { offcanvas: offcanvasElement }
    });
    offcanvasElement.dispatchEvent(showEvent);
  }

  hide(event) {
    if (event) event.preventDefault();

    const offcanvasElement = this.getOffcanvasElement(event);
    if (!offcanvasElement) return;

    // Hide offcanvas
    offcanvasElement.classList.remove("show");

    // Remove backdrop after animation
    setTimeout(() => {
      if (this.backdrop) {
        this.backdrop.remove();
        this.backdrop = null;
      }
      offcanvasElement.style.visibility = "hidden";

      // Restore body scroll
      document.body.style.overflow = "";
    }, 300);

    // Remove event listeners
    this.removeEventListeners();

    // Trigger custom event
    const hideEvent = new CustomEvent("offcanvas:hidden", {
      detail: { offcanvas: offcanvasElement }
    });
    offcanvasElement.dispatchEvent(hideEvent);
  }

  dismiss(event) {
    // Handle dismiss from close button or backdrop
    this.hide(event);
  }

  getOffcanvasElement(event) {
    if (this.hasOffcanvasTarget) {
      return this.offcanvasTarget;
    }

    // If triggered by data-bs-target attribute
    if (event && event.currentTarget) {
      const target = event.currentTarget.dataset.bsTarget;
      if (target) {
        return document.querySelector(target);
      }
    }

    // Look for closest offcanvas element
    if (event && event.currentTarget) {
      return event.currentTarget.closest(".offcanvas");
    }

    return null;
  }

  createBackdrop() {
    if (this.backdrop) return;

    this.backdrop = document.createElement("div");
    this.backdrop.className = "offcanvas-backdrop fade show";
    this.backdrop.addEventListener("click", () => this.hide());

    document.body.appendChild(this.backdrop);
  }

  addEventListeners(offcanvasElement) {
    // ESC key handler
    this.escapeKeyHandler = (e) => {
      if (e.key === "Escape") this.hide();
    };
    document.addEventListener("keydown", this.escapeKeyHandler);

    // Close button handlers
    const closeButtons = offcanvasElement.querySelectorAll('[data-bs-dismiss="offcanvas"], .btn-close');
    closeButtons.forEach((btn) => {
      btn.addEventListener("click", () => this.hide());
    });
  }

  removeEventListeners() {
    // Remove escape key handler
    if (this.escapeKeyHandler) {
      document.removeEventListener("keydown", this.escapeKeyHandler);
      this.escapeKeyHandler = null;
    }
  }

  disconnect() {
    // Clean up when controller is disconnected
    this.removeEventListeners();
    if (this.backdrop) {
      this.backdrop.remove();
      this.backdrop = null;
    }
    document.body.style.overflow = "";
  }

  // Static method for programmatic control
  static getInstance(element) {
    return element.stimulus?.controllers?.find(c => c.identifier === "offcanvas");
  }
}

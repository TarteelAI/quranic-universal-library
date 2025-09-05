import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["alert"];

  connect() {
    // Auto-initialize if this controller is on an alert element
    if (this.element.classList.contains("alert")) {
      this.alertTarget = this.element;
    }

    // Set up global alert dismiss handlers when controller connects
    this.setupGlobalHandlers();
  }

  setupGlobalHandlers() {
    // Handle alert dismiss buttons globally with multiple fallback strategies
    if (!document.alertHandlersSetup) {
      document.alertHandlersSetup = true;

      // Global event delegation for all alert dismiss buttons
      document.addEventListener(
        "click",
        this.handleGlobalAlertDismiss.bind(this),
      );

      // Handle Turbo page loads
      document.addEventListener("turbo:load", this.handleTurboLoad.bind(this));
    }
  }

  handleGlobalAlertDismiss(event) {
    const target = event.target;

    // Check for various dismiss button patterns
    if (
      target.matches('[data-action="click->alert#dismiss"]') ||
      target.matches(".alert .btn-close") ||
      target.matches('[data-bs-dismiss="alert"]')
    ) {
      event.preventDefault();
      this.dismissAlert(target);
    }
  }

  handleTurboLoad() {
    // Re-attach handlers after Turbo navigation for any missed elements
    setTimeout(() => {
      const alertButtons = document.querySelectorAll(".alert .btn-close");
      alertButtons.forEach((button) => {
        if (!button.dataset.alertHandlerAttached) {
          button.dataset.alertHandlerAttached = "true";
          button.addEventListener("click", (e) => {
            e.preventDefault();
            this.dismissAlert(button);
          });
        }
      });
    }, 100);
  }

  dismiss(event) {
    event.preventDefault();
    this.dismissAlert(event.currentTarget);
  }

  dismissAlert(triggerElement) {
    // Find the alert element using multiple strategies
    let alertElement = this.hasAlertTarget
      ? this.alertTarget
      : this.findAlertElement(triggerElement);

    if (alertElement) {
      // Add fade out animation
      alertElement.style.transition = "opacity 0.15s linear";
      alertElement.style.opacity = "0";

      // Remove element after animation completes
      setTimeout(() => {
        alertElement.remove();
      }, 150);
    }
  }

  findAlertElement(triggerElement) {
    // Multiple strategies to find the alert element
    return (
      triggerElement.closest(".alert") ||
      triggerElement.closest('[role="alert"]') ||
      triggerElement.closest(".alert-dismissible") ||
      (this.element.classList.contains("alert") ? this.element : null)
    );
  }

  // Static method to create dismissible alerts programmatically
  static create(message, type = "info", dismissible = true) {
    const alertElement = document.createElement("div");
    alertElement.className = `alert alert-${type}${dismissible ? " alert-dismissible" : ""} d-flex`;
    alertElement.setAttribute("role", "alert");
    alertElement.setAttribute("data-controller", "alert");

    let iconClass;
    switch (type) {
      case "success":
        iconClass = "fa-check-circle";
        break;
      case "danger":
        iconClass = "fa-exclamation-circle";
        break;
      case "warning":
        iconClass = "fa-exclamation-triangle";
        break;
      default:
        iconClass = "fa-info-circle";
    }

    alertElement.innerHTML = `
      <i class="fa ${iconClass} me-2"></i>
      <div class="flex-grow-1">${message}</div>
      ${dismissible ? '<button type="button" class="btn-close" data-action="click->alert#dismiss" aria-label="Close"></button>' : ""}
    `;

    return alertElement;
  }
}

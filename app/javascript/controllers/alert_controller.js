import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["alert"];

  connect() {
    // Auto-initialize if this controller is on an alert element
    if (this.element.classList.contains("alert")) {
      this.alertTarget = this.element;
    }
  }

  dismiss(event) {
    event.preventDefault();

    // Find the alert element - either the target or closest parent with alert class
    let alertElement = this.hasAlertTarget
      ? this.alertTarget
      : event.currentTarget.closest(".alert");

    // If still not found, check if the current element is the alert
    if (!alertElement && this.element.classList.contains("alert")) {
      alertElement = this.element;
    }

    // If still not found, traverse up from the clicked element
    if (!alertElement) {
      alertElement = event.target.closest(".alert");
    }

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

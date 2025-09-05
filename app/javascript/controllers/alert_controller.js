import { Controller } from "@hotwired/stimulus";

// Set up global alert handlers immediately when this module loads
if (!window.alertHandlersSetup) {
  window.alertHandlersSetup = true;

  // Global event delegation for all alert dismiss buttons
  document.addEventListener("click", (event) => {
    const target = event.target;

    // Check for various dismiss button patterns
    if (
      target.matches('[data-action="click->alert#dismiss"]') ||
      target.matches(".alert .btn-close") ||
      target.matches('[data-bs-dismiss="alert"]')
    ) {
      event.preventDefault();
      dismissAlert(target);
    }
  });

  // Handle Turbo page loads
  document.addEventListener("turbo:load", () => {
    setTimeout(() => {
      const alertButtons = document.querySelectorAll(".alert .btn-close");
      alertButtons.forEach((button) => {
        if (!button.dataset.alertHandlerAttached) {
          button.dataset.alertHandlerAttached = "true";
          button.addEventListener("click", (e) => {
            e.preventDefault();
            dismissAlert(button);
          });
        }
      });
    }, 100);
  });

  // Also handle DOMContentLoaded for initial page load
  document.addEventListener("DOMContentLoaded", () => {
    const alertButtons = document.querySelectorAll(".alert .btn-close");
    alertButtons.forEach((button) => {
      if (!button.dataset.alertHandlerAttached) {
        button.dataset.alertHandlerAttached = "true";
        button.addEventListener("click", (e) => {
          e.preventDefault();
          dismissAlert(button);
        });
      }
    });
  });
}

// Global dismiss function
function dismissAlert(triggerElement) {
  // Find the alert element using multiple strategies
  const alertElement =
    triggerElement.closest(".alert") ||
    triggerElement.closest('[role="alert"]') ||
    triggerElement.closest(".alert-dismissible");

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
    dismissAlert(event.currentTarget);
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

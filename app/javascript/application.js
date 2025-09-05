// Entry point for the build script in your package.json
import "./libs/jquery";
import "@hotwired/turbo-rails";

import "trix";
import "@rails/actiontext";
import "./controllers";
import "./utils/ayah-player";

// Robust alert dismiss functionality with multiple fallbacks
document.addEventListener("DOMContentLoaded", () => {
  // Handle alert dismiss buttons with multiple selectors
  document.addEventListener("click", (event) => {
    const target = event.target;

    // Check for various dismiss button patterns
    if (
      target.matches('[data-action="click->alert#dismiss"]') ||
      target.matches(".alert .btn-close") ||
      target.matches('[data-bs-dismiss="alert"]')
    ) {
      event.preventDefault();

      // Find the alert element using multiple strategies
      let alertElement =
        target.closest(".alert") ||
        target.closest('[role="alert"]') ||
        target.closest(".alert-dismissible");

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
  });
});

// Also handle Turbo page loads
document.addEventListener("turbo:load", () => {
  // Re-attach handlers after Turbo navigation
  setTimeout(() => {
    const alertButtons = document.querySelectorAll(".alert .btn-close");
    alertButtons.forEach((button) => {
      if (!button.dataset.alertHandlerAttached) {
        button.dataset.alertHandlerAttached = "true";
        button.addEventListener("click", (e) => {
          e.preventDefault();
          const alert = button.closest(".alert");
          if (alert) {
            alert.style.transition = "opacity 0.15s linear";
            alert.style.opacity = "0";
            setTimeout(() => alert.remove(), 150);
          }
        });
      }
    });
  }, 100);
});

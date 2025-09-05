// Entry point for the build script in your package.json
import "./libs/jquery";
import "@hotwired/turbo-rails";

import "trix";
import "@rails/actiontext";
import "./controllers";
import "./utils/ayah-player";

// Alert dismiss functionality - working immediately
document.addEventListener("DOMContentLoaded", () => {
  setupAlertHandlers();
});

document.addEventListener("turbo:load", () => {
  setupAlertHandlers();
});

function setupAlertHandlers() {
  const alertButtons = document.querySelectorAll(
    '.alert .btn-close, [data-action="click->alert#dismiss"], [data-bs-dismiss="alert"]',
  );

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
}

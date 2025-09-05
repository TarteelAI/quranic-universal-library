import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "pane"];
  static values = { activeTab: String };

  connect() {
    // Set initial active tab
    this.showInitialTab();
  }

  showInitialTab() {
    // Find the active tab or default to first tab
    let activeTab = this.tabTargets.find(tab =>
      tab.classList.contains("active") ||
      tab.getAttribute("aria-selected") === "true"
    );

    if (!activeTab && this.tabTargets.length > 0) {
      activeTab = this.tabTargets[0];
    }

    if (activeTab) {
      this.showTab({ currentTarget: activeTab });
    }
  }

  showTab(event) {
    event.preventDefault();
    const clickedTab = event.currentTarget;
    const targetPaneId = clickedTab.getAttribute("data-bs-target") ||
                        clickedTab.getAttribute("aria-controls");

    if (!targetPaneId) return;

    // Remove active class from all tabs
    this.tabTargets.forEach(tab => {
      tab.classList.remove("active");
      tab.setAttribute("aria-selected", "false");
    });

    // Remove active class from all panes
    this.paneTargets.forEach(pane => {
      pane.classList.remove("active", "show");
    });

    // Add active class to clicked tab
    clickedTab.classList.add("active");
    clickedTab.setAttribute("aria-selected", "true");

    // Show target pane
    const targetPane = document.querySelector(targetPaneId) ||
                      this.paneTargets.find(pane =>
                        pane.id === targetPaneId.replace("#", "")
                      );

    if (targetPane) {
      targetPane.classList.add("active", "show");
    }

    // Store active tab value
    this.activeTabValue = clickedTab.id || clickedTab.getAttribute("aria-controls");

    // Trigger custom event
    const tabShownEvent = new CustomEvent("tab:shown", {
      detail: {
        tab: clickedTab,
        pane: targetPane
      }
    });
    this.element.dispatchEvent(tabShownEvent);
  }
}

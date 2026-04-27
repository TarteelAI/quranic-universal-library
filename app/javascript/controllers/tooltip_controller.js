import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 8 }
  }

  connect() {
    // Determine the title, prioritizing our cached version to survive re-connections
    this.title = this.element.dataset.qulTooltipTitle || 
                 this.element.getAttribute("title") || 
                 this.element.dataset.title;
    
    if (!this.title || !this.title.trim()) return;

    // Cache it in a data attribute that doesn't trigger tooltips naturally
    this.element.dataset.qulTooltipTitle = this.title;
    
    // Remove the native title to prevent double tooltips
    this.element.removeAttribute("title");

    this.showTooltip = this.showTooltip.bind(this);
    this.hideTooltip = this.hideTooltip.bind(this);

    this.element.addEventListener("mouseenter", this.showTooltip);
    this.element.addEventListener("mouseleave", this.hideTooltip);
    // Use focusin/out for accessibility but add tabIndex if needed (handled in views usually)
    this.element.addEventListener("focusin", this.showTooltip);
    this.element.addEventListener("focusout", this.hideTooltip);
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.showTooltip);
    this.element.removeEventListener("mouseleave", this.hideTooltip);
    this.element.removeEventListener("focusin", this.showTooltip);
    this.element.removeEventListener("focusout", this.hideTooltip);
    this.removeTooltip();
  }

  showTooltip() {
    // Ensure we don't have multiple tooltips
    this.removeTooltip();

    // Create the tooltip element
    this.tooltip = document.createElement("div");
    this.tooltip.setAttribute("role", "tooltip");
    
    // Apply styles directly to be safe from purge or config issues
    // Using  classes for theme consistency
    this.tooltip.className = "fixed z-[99999] px-3 py-1.5 text-[11px] font-medium text-white bg-gray-900 rounded shadow-xl pointer-events-none whitespace-nowrap leading-tight";
    
    // Explicit visibility management
    this.tooltip.style.opacity = "0";
    this.tooltip.style.visibility = "hidden";
    this.tooltip.style.display = "block";
    this.tooltip.textContent = this.title;
    
    // Add the arrow
    this.arrow = document.createElement("div");
    this.arrow.className = "absolute w-2 h-2 bg-gray-900 rotate-45";
    this.tooltip.appendChild(this.arrow);

    document.body.appendChild(this.tooltip);

    // Give the browser a moment to layout the tooltip so we can measure it
    // offsetWidth only works if display != none
    requestAnimationFrame(() => {
      this.updatePosition();
      if (this.tooltip) {
        this.tooltip.style.visibility = "visible";
        this.tooltip.style.opacity = "1";
        // Smooth transition
        this.tooltip.style.transition = "opacity 0.1s ease-out, transform 0.1s ease-out";
      }
    });
  }

  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.style.opacity = "0";
      const el = this.tooltip;
      // Faster cleanup
      setTimeout(() => {
        if (el && el.parentNode) el.parentNode.removeChild(el);
      }, 100);
      this.tooltip = null;
    }
  }

  removeTooltip() {
    const existing = document.body.querySelectorAll('div[role="tooltip"]');
    existing.forEach(el => {
      if (el.parentNode) el.parentNode.removeChild(el);
    });
    this.tooltip = null;
  }

  updatePosition() {
    if (!this.tooltip) return;

    const rect = this.element.getBoundingClientRect();
    const tipWidth = this.tooltip.offsetWidth;
    const tipHeight = this.tooltip.offsetHeight;
    
    // We use getBoundingClientRect for the button, 
    // and since the tooltip is fixed, we coordinate directly with it.
    
    const centerX = rect.left + (rect.width / 2);
    const centerY = rect.top + (rect.height / 2);
    
    let x = 0;
    let y = 0;
    let arrowStyle = {};

    const placement = this.placementValue || "top";
    const offset = this.offsetValue || 8;

    if (placement === "top") {
      x = centerX - (tipWidth / 2);
      y = rect.top - tipHeight - offset;
      arrowStyle = { bottom: "-4px", left: "50%", marginLeft: "-4px" };
    } else if (placement === "bottom") {
      x = centerX - (tipWidth / 2);
      y = rect.bottom + offset;
      arrowStyle = { top: "-4px", left: "50%", marginLeft: "-4px" };
    } else if (placement === "left") {
      x = rect.left - tipWidth - offset;
      y = centerY - (tipHeight / 2);
      arrowStyle = { right: "-4px", top: "50%", marginTop: "-4px" };
    } else if (placement === "right") {
      x = rect.right + offset;
      y = centerY - (tipHeight / 2);
      arrowStyle = { left: "-4px", top: "50%", marginTop: "-4px" };
    }

    // Viewport collision protection (keep 10px from edges)
    const padding = 10;
    x = Math.max(padding, Math.min(x, window.innerWidth - tipWidth - padding));
    y = Math.max(padding, Math.min(y, window.innerHeight - tipHeight - padding));

    this.tooltip.style.left = `${x}px`;
    this.tooltip.style.top = `${y}px`;
    
    // Fine-tune arrow position if the tooltip was shifted by padding logic
    if (placement === "top" || placement === "bottom") {
      const idealX = centerX - (tipWidth / 2);
      const shift = idealX - x;
      const arrowLeft = (tipWidth / 2) + shift;
      // Constrain arrow within the tooltip width
      this.arrow.style.left = `${Math.max(8, Math.min(tipWidth - 8, arrowLeft))}px`;
    }

    Object.assign(this.arrow.style, arrowStyle);
  }
}
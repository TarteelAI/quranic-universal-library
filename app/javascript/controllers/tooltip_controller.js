import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    html: { type: Boolean, default: true },
    placement: { type: String, default: "top" },
    text: { type: String, default: "" }
  };

  connect() {
    this.title =
      this.textValue ||
      this.element.getAttribute("title") ||
      this.element.dataset.title;

    if (!this.title || !this.title.trim()) return;

    this.originalTitle = this.title;
    this.element.removeAttribute("title");

    this.tooltip = document.createElement("div");
    this.tooltip.className =
      "tw-absolute tw-z-[10000] tw-px-3 tw-py-2 tw-text-sm tw-text-white tw-bg-gray-900 tw-rounded-md tw-shadow-xl tw-pointer-events-none tw-opacity-0 tw-transition-opacity tw-duration-200 tw-max-w-xs tw-whitespace-normal";
    this.tooltip.setAttribute("role", "tooltip");
    this.tooltip.style.visibility = "hidden";
    this.tooltip.style.display = "none";
    this.tooltip.style.position = "fixed";

    this.contentWrapper = document.createElement("div");
    this.setContent(this.title);
    this.tooltip.appendChild(this.contentWrapper);

    this.arrow = document.createElement("div");
    this.arrow.className = "tw-absolute tw-w-0 tw-h-0";
    this.arrow.style.pointerEvents = "none";
    this.tooltip.appendChild(this.arrow);

    this.updateArrowDirection(this.placementValue);

    document.body.appendChild(this.tooltip);

    this.showTooltip = this.showTooltip.bind(this);
    this.hideTooltip = this.hideTooltip.bind(this);
    this.handleUpdate = this.handleUpdate.bind(this);

    this.element.addEventListener("mouseenter", this.showTooltip);
    this.element.addEventListener("mouseleave", this.hideTooltip);
    this.element.addEventListener("focus", this.showTooltip);
    this.element.addEventListener("blur", this.hideTooltip);
    this.element.addEventListener("tooltip:update", this.handleUpdate);
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.showTooltip);
    this.element.removeEventListener("mouseleave", this.hideTooltip);
    this.element.removeEventListener("focus", this.showTooltip);
    this.element.removeEventListener("blur", this.hideTooltip);
    this.element.removeEventListener("tooltip:update", this.handleUpdate);

    if (this.tooltip?.parentNode) {
      this.tooltip.parentNode.removeChild(this.tooltip);
    }

    if (this.originalTitle) {
      this.element.setAttribute("title", this.originalTitle);
    }
  }

  setContent(text) {
    if (this.htmlValue) {
      this.contentWrapper.innerHTML = text;
    } else {
      this.contentWrapper.textContent = text;
    }
  }

  handleUpdate(event) {
    const { text, temporary } = event.detail || {};
    if (!text) return;

    this.setContent(text);
    this.showTooltip();

    this.updatePosition();

    if (temporary) {
      clearTimeout(this.resetTimer);
      this.resetTimer = setTimeout(() => {
        this.setContent(this.originalTitle);
        this.updatePosition();
      }, 1500);
    }
  }

  showTooltip() {
    if (!this.tooltip) return;

    this.tooltip.style.display = "block";
    this.tooltip.style.visibility = "hidden";
    this.tooltip.style.left = "-9999px";
    this.tooltip.style.top = "0px";

    void this.tooltip.offsetWidth;

    this.updatePosition();

    this.tooltip.style.visibility = "visible";
    this.tooltip.classList.remove("tw-opacity-0");
    this.tooltip.classList.add("tw-opacity-100");
  }

  hideTooltip() {
    if (!this.tooltip) return;

    this.tooltip.classList.remove("tw-opacity-100");
    this.tooltip.classList.add("tw-opacity-0");
    this.tooltip.style.visibility = "hidden";
    this.tooltip.style.display = "none";
  }

  updatePosition() {
    const elementRect = this.element.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();

    const tooltipWidth = tooltipRect.width || this.tooltip.offsetWidth;
    const tooltipHeight = tooltipRect.height || this.tooltip.offsetHeight;

    const offset = 8;
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    let placement = this.placementValue;
    let x = 0;
    let y = 0;

    const spaceTop = elementRect.top;
    const spaceBottom = viewportHeight - elementRect.bottom;

    if (placement === "top" && spaceTop < tooltipHeight + offset) {
      placement = "bottom";
    } else if (placement === "bottom" && spaceBottom < tooltipHeight + offset) {
      placement = "top";
    }

    this.updateArrowDirection(placement);

    switch (placement) {
      case "top":
        x =
          elementRect.left +
          elementRect.width / 2 -
          tooltipWidth / 2;
        y = elementRect.top - tooltipHeight - offset;
        break;
      case "bottom":
        x =
          elementRect.left +
          elementRect.width / 2 -
          tooltipWidth / 2;
        y = elementRect.bottom + offset;
        break;
      case "left":
        x = elementRect.left - tooltipWidth - offset;
        y =
          elementRect.top +
          elementRect.height / 2 -
          tooltipHeight / 2;
        break;
      case "right":
        x = elementRect.right + offset;
        y =
          elementRect.top +
          elementRect.height / 2 -
          tooltipHeight / 2;
        break;
    }

    const padding = 8;
    x = Math.max(padding, Math.min(x, viewportWidth - tooltipWidth - padding));
    y = Math.max(padding, Math.min(y, viewportHeight - tooltipHeight - padding));

    this.tooltip.style.left = `${x}px`;
    this.tooltip.style.top = `${y}px`;
  }

  updateArrowDirection(placement) {
    Object.assign(this.arrow.style, {
      borderLeft: "",
      borderRight: "",
      borderTop: "",
      borderBottom: "",
      top: "",
      bottom: "",
      left: "",
      right: "",
      marginLeft: "",
      marginTop: ""
    });

    const arrowColor = "rgb(17, 24, 39)";

    switch (placement) {
      case "top":
        this.arrow.style.borderLeft = "6px solid transparent";
        this.arrow.style.borderRight = "6px solid transparent";
        this.arrow.style.borderTop = `6px solid ${arrowColor}`;
        this.arrow.style.bottom = "-6px";
        this.arrow.style.left = "50%";
        this.arrow.style.marginLeft = "-6px";
        break;
      case "bottom":
        this.arrow.style.borderLeft = "6px solid transparent";
        this.arrow.style.borderRight = "6px solid transparent";
        this.arrow.style.borderBottom = `6px solid ${arrowColor}`;
        this.arrow.style.top = "-6px";
        this.arrow.style.left = "50%";
        this.arrow.style.marginLeft = "-6px";
        break;
      case "left":
        this.arrow.style.borderTop = "6px solid transparent";
        this.arrow.style.borderBottom = "6px solid transparent";
        this.arrow.style.borderRight = `6px solid ${arrowColor}`;
        this.arrow.style.right = "-6px";
        this.arrow.style.top = "50%";
        this.arrow.style.marginTop = "-6px";
        break;
      case "right":
        this.arrow.style.borderTop = "6px solid transparent";
        this.arrow.style.borderBottom = "6px solid transparent";
        this.arrow.style.borderLeft = `6px solid ${arrowColor}`;
        this.arrow.style.left = "-6px";
        this.arrow.style.top = "50%";
        this.arrow.style.marginTop = "-6px";
        break;
    }
  }
}
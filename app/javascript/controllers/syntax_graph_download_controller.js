import { Controller } from "@hotwired/stimulus";
import domtoimage from "dom-to-image-more";

export default class extends Controller {
  static targets = ["graphContainer"];

  async download(event) {
    if (event) event.preventDefault();

    const button = event?.currentTarget;
    let originalHtml;

    if (button) {
      originalHtml = button.innerHTML;
      button.disabled = true;
      button.classList.add("tw-opacity-70", "tw-cursor-not-allowed");
      button.innerHTML = '<i class="fa fa-spinner fa-spin"></i>';
    }

    if (!this.hasGraphContainerTarget) {
      if (button) {
        button.disabled = false;
        button.classList.remove("tw-opacity-70", "tw-cursor-not-allowed");
        if (originalHtml) button.innerHTML = originalHtml;
      }
      return;
    }

    const container = this.graphContainerTarget;
    const svg = container.querySelector("svg");
    if (!svg) {
      console.warn("No syntax graph SVG found to download.");
      if (button) {
        button.disabled = false;
        button.classList.remove("tw-opacity-70", "tw-cursor-not-allowed");
        if (originalHtml) button.innerHTML = originalHtml;
      }
      return;
    }

    try {
      if (document.fonts && document.fonts.ready) {
        await document.fonts.ready;
      }

      const dataUrl = await domtoimage.toPng(container, {
        bgcolor: "#fff",
        scale: 2,
        style: {
          transform: "scale(1)",
          transformOrigin: "top left",
        },
      });

      const link = document.createElement("a");
      link.href = dataUrl;

      const baseName =
        container.dataset.syntaxGraphFilenameValue || "syntax-graph";
      link.download = `${baseName}.png`;

      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error("Failed to export syntax graph:", error);
    } finally {
      if (button) {
        button.disabled = false;
        button.classList.remove("tw-opacity-70", "tw-cursor-not-allowed");
        if (originalHtml) button.innerHTML = originalHtml;
      }
    }
  }
}

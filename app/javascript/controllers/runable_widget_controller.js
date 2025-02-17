import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.codeDom = this.element.querySelector("code");
    this.code = this.codeDom.innerText;

    this.createPreviewDom();
    this.createRunButton();
  }

  createRunButton() {
    const button = document.createElement("button");
    button.innerText = "Run";
    button.style.position = "absolute";
    button.style.top = "5px";
    button.style.right = "5px";
    button.style.background = "#4CAF50";
    button.style.color = "white";
    button.style.border = "none";
    button.style.padding = "5px 10px";
    button.style.borderRadius = "4px";
    button.style.cursor = "pointer";
    button.style.fontSize = "12px";

    button.addEventListener("click", () => this.runCode());

    this.element.style.position = "relative"; // Ensure the <code> is positioned
    this.element.appendChild(button);
  }

  createPreviewDom(){
    this.previewDiv = document.createElement("div");
    this.previewDiv.id = "run-preview";
    this.previewDiv.style.marginTop = "10px";
    this.previewDiv.style.padding = "10px";
    this.previewDiv.style.border = "1px solid #ccc";
    this.previewDiv.style.minHeight = "50px";
    this.previewDiv.style.overflow = "auto";
    this.previewDiv.style.background = "#f9f9f9";

    this.element.insertAdjacentElement("afterend", this.previewDiv);
  }

  runCode() {
    this.previewDiv.innerHTML = "";
    this.previewDiv.scrollIntoView({ behavior: "smooth" });

    try {
      eval(this.code);
    } catch (error) {
      console.error("Error executing code:", error);
    }
  }
}
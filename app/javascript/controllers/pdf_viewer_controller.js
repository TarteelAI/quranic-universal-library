import { Controller } from "@hotwired/stimulus";
import PDFViewer from "../utils/pdf_viewer";
import { loadJavascript } from '../utils/script_loader';

export default class extends Controller {
  connect() {
    this.isInitialized = false;
    loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.8.162/pdf.min.js").then(this.initPdfViewer.bind(this));
  }

  initPdfViewer() {
    if(this.isInitialized) return;
    this.isInitialized = true;
    const { pdfUrl, page, pageOffset } = this.element.dataset;

    // Add controls to the DOM
    $(this.element).prepend(this.controlHtml(pageOffset));

    // Initialize the PDF viewer
    const pdfViewer = new PDFViewer(pdfUrl, this.element, parseInt(page || 1), parseInt(pageOffset || 0));
    pdfViewer.init();

    // Attach event listeners for controls
    this.attachEventListeners(pdfViewer);
  }

  controlHtml(offset) {
    return `
      <div id="controls" class="text-center mb-3 border-bottom p-2 resize-heading">
        <button id="prevBtn" disabled>Previous</button>
        <button id="nextBtn" disabled>Next</button>

        <button id="zoomInBtn" disabled>+</button>
        <button id="zoomOutBtn" disabled>-</button>

        <select id="pageDropdown" disabled>
          <option value="1">Page 1</option>
        </select>
        <small>offset(${offset})</small>
        <label>
          <input type="checkbox" checked id="pdf-fit-viewport"> Fit parent
        </label>
      </div>
    `;
  }

  attachEventListeners(pdfViewer) {
    const prevBtn = this.element.querySelector("#prevBtn");
    const nextBtn = this.element.querySelector("#nextBtn");
    const zoomInBtn = this.element.querySelector("#zoomInBtn");
    const zoomOutBtn = this.element.querySelector("#zoomOutBtn");
    const pageDropdown = this.element.querySelector("#pageDropdown");
    const fitViewportCheckbox = this.element.querySelector("#pdf-fit-viewport");

    // Enable buttons once the PDF is loaded
    pdfViewer.onLoad(() => {
      prevBtn.disabled = false;
      nextBtn.disabled = false;
      zoomInBtn.disabled = false;
      zoomOutBtn.disabled = false;
      pageDropdown.disabled = false;

      // Populate the page dropdown
      for (let i = 1; i <= pdfViewer.totalPages; i++) {
        pageDropdown.innerHTML += `<option value="${i}">Page ${i}</option>`;
      }
    });

    // Handle previous button click
    prevBtn.addEventListener("click", () => {
      pdfViewer.prevPage();
      pageDropdown.value = pdfViewer.currentPage;
    });

    // Handle next button click
    nextBtn.addEventListener("click", () => {
      pdfViewer.nextPage();
      pageDropdown.value = pdfViewer.currentPage;
    });

    // Handle page dropdown change
    pageDropdown.addEventListener("change", (e) => {
      const pageNumber = parseInt(e.target.value);
      pdfViewer.jumpToPage(pageNumber);
    });

    // Handle zoom in
    zoomInBtn.addEventListener("click", () => {
      pdfViewer.zoomIn();
    });

    // Handle zoom out
    zoomOutBtn.addEventListener("click", () => {
      pdfViewer.zoomOut();
    });

    // Handle fit viewport checkbox
    fitViewportCheckbox.addEventListener("change", (e) => {
      pdfViewer.setFitViewport(e.target.checked);
    });
  }
}
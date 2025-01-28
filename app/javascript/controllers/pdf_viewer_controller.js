import { Controller } from "@hotwired/stimulus";
import PDFViewer from "../utils/pdf_viewer";
import { loadJavascript } from '../utils/script_loader';

export default class extends Controller {
  connect() {
    if(!this.element.dataset.initialized){
      loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.8.162/pdf.min.js").then(this.initPdfViewer.bind(this));
    }
  }

  initPdfViewer() {
    this.element.dataset.initialized = true

    const { pdfUrl, page, pageOffset } = this.element.dataset;

    $(this.element).prepend(this.controlHtml(pageOffset));

    const pdfViewer = new PDFViewer(pdfUrl, this.element, parseInt(page || 1), parseInt(pageOffset || 0));
    pdfViewer.init();

    this.attachEventListeners(pdfViewer);
  }

  controlHtml(offset) {
    return `
      <div id="controls" class="d-flex justify-content-between mb-3 border-bottom p-2 resize-heading">
        <div class="d-flex justify-content-between">
          <div class="me-2">
            <button id="prevBtn" class="btn btn-info btn-xs" disabled>Previous</button>
            <button id="nextBtn" class="btn btn-info btn-xs" disabled>Next</button>
          </div>
         
         <div>
           <button id="zoomInBtn" class="btn btn-primary btn-xs" disabled>+</button>
          <button id="zoomOutBtn" class="btn btn-primary btn-xs" disabled>-</button>  
         </div> 
        </div>
        
        <div>
        <select id="pageDropdown" disabled>
          <option value="1">Page 1</option>
        </select>
        <small>offset(${offset||0})</small>
        <label>
          <input type="checkbox" checked id="pdf-fit-viewport"> Fit parent
        </label>
</div>
        
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
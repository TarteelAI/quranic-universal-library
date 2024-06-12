import { Controller } from "@hotwired/stimulus"
import PDFViewer from "../utils/pdf_viewer";
import {loadJavascript} from '../utils/script_loader';

export default class extends Controller {
  connect() {
    loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.8.162/pdf.min.js").then(this.initPdfViewer.bind(this))
  }

  initPdfViewer(){
    const {pdfUrl, page, pageOffset} = this.element.dataset;

    $(this.element).prepend(this.controlHtml(pageOffset))
    const pdfViewer = new PDFViewer(pdfUrl, this.element, page);
    pdfViewer.init();
  }

  controlHtml(offset){
    return `<div id="controls" class="text-center mb-3 border-bottom p-2 resize-heading">
          <button id="prevBtn" disabled>Previous</button>
          <button id="nextBtn" disabled>Next</button>

          <button id="zoomInBtn" disabled>+</button>
          <button id="zoomOutBtn" disabled>-</button>

          <select id="pageDropdown" disabled>
          </select>
          <small>offset(${offset})</small>
          <label>
            <input type="checkbox" checked id="pdf-fit-viewport"> Fit parent
          </label>
        </div>`
  }
}

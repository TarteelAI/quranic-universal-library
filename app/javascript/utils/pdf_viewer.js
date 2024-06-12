class PDFViewer {
  constructor(pdfURL, context, page) {
    this.maxScale = 3.0;
    this.minScale = 0.5;
    this.currentScale = 1.0;
    this.zoomLevel = 0;

    this.pdfURL = pdfURL;
    this.pdfDoc = null;
    this.currentPage = Number(page || 1);
    this.fitParent = context.querySelector('#pdf-fit-viewport')
    this.pdfContainer = context.querySelector('#pdf-container');
    this.canvas = context.querySelector('#pdf-canvas');
    this.prevBtn = context.querySelector('#prevBtn');
    this.nextBtn = context.querySelector('#nextBtn');
    this.zoomInBtn = context.querySelector('#zoomInBtn');
    this.zoomOutBtn = context.querySelector('#zoomOutBtn');

    this.pageDropdown = context.querySelector('#pageDropdown');

    this.pageDropdown.addEventListener('change', this.jumpToPage.bind(this))
    this.fitParent.addEventListener('change', this.toggleCanvasFit.bind(this))

    this.prevBtn.addEventListener('click', this.prevPage.bind(this))
    this.nextBtn.addEventListener('click', this.nextPage.bind(this))
    this.zoomInBtn.addEventListener('click', this.zoomIn.bind(this))
    this.zoomOutBtn.addEventListener('click', this.zoomOut.bind(this))
    this.toggleCanvasFit();
  }

  async init() {
    // Asynchronous loading of pdf.js
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.8.162/pdf.worker.min.js';

    // Initialize the lazy-loading using Intersection Observer
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          this.loadPDF();
          observer.unobserve(entry.target);
        }
      });
    });

    observer.observe(this.pdfContainer);
  }

  async loadPDF() {
    this.pdfDoc = await pdfjsLib.getDocument(this.pdfURL).promise;
    const numPages = this.pdfDoc.numPages;

    // Populate the dropdown with page options
    for (let i = 1; i <= numPages; i++) {
      const option = document.createElement('option');
      option.value = i;
      option.text = `Page ${i}`;
      this.pageDropdown.appendChild(option);
    }

    // Enable controls after PDF is loaded
    this.prevBtn.disabled = false;
    this.nextBtn.disabled = false;
    this.pageDropdown.disabled = false;
    this.zoomInBtn.disabled = false;
    this.zoomOutBtn.disabled = false;

    this.renderPage(this.currentPage);
    this.updateControls()
  }

  async renderPage(pageNum) {
    const page = await this.pdfDoc.getPage(pageNum);
    const scale = this.pdfContainer.clientWidth / page.getViewport({scale: this.currentScale}).width;
    const viewport = page.getViewport({scale});
    this.canvas.height = viewport.height;
    this.canvas.width = viewport.width;
    const context = this.canvas.getContext('2d');

    const renderContext = {
      canvasContext: context,
      viewport: viewport
    };
    await page.render(renderContext);
  }

  toggleCanvasFit() {
    if (this.fitParent.checked)
      this.canvas.classList.add('w-100')
    else{
      this.canvas.classList.remove('w-100')
      this.renderPage(this.currentPage);
    }
  }

  prevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.renderPage(this.currentPage);
      this.updateControls();
    }
  }

  nextPage() {
    if (this.currentPage < this.pdfDoc.numPages) {
      this.currentPage++;
      this.renderPage(this.currentPage);
      this.updateControls();
    }
  }

  jumpToPage() {
    const selectedPage = parseInt(this.pageDropdown.value);
    if (selectedPage >= 1 && selectedPage <= this.pdfDoc.numPages) {
      this.currentPage = selectedPage;
      this.renderPage(this.currentPage);
      this.updateControls();
    }
  }

  updateControls() {
    this.prevBtn.disabled = this.currentPage === 1;
    this.nextBtn.disabled = this.currentPage === this.pdfDoc.numPages;
    this.pageDropdown.value = this.currentPage;
  }

   zoomIn() {
    if (this.currentScale < this.maxScale) {
      this.currentScale += 0.1;
      this.zoomLevel++;
      this.updateZoom();
    }
  }

   zoomOut() {
    if (this.currentScale > this.minScale) {
      this.currentScale -= 0.1;
      this.zoomLevel--;
      this.updateZoom();
    }
  }

   updateZoom() {
    const padding = Math.max(0, this.zoomLevel * 50);
     this.pdfContainer.style.paddingTop = `${Number(padding)}px`;
     this.canvas.style.transform = `scale(${this.currentScale})`;
  }
}

export default PDFViewer;


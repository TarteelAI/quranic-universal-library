class PDFViewer {
  constructor(pdfURL, context, page) {
    this.maxScale = 3.0;
    this.minScale = 0.5;
    this.currentScale = 1.0;
    this.zoomLevel = 0;

    this.pdfURL = pdfURL;
    this.pdfDoc = null;
    this.currentPage = Number(page || 1);
    this.totalPages = 0;

    this.fitParent = context.querySelector('#pdf-fit-viewport');
    this.pdfContainer = context.querySelector('#pdf-container');
    this.canvas = context.querySelector('#pdf-canvas');
    this.prevBtn = context.querySelector('#prevBtn');
    this.nextBtn = context.querySelector('#nextBtn');
    this.zoomInBtn = context.querySelector('#zoomInBtn');
    this.zoomOutBtn = context.querySelector('#zoomOutBtn');
    this.pageDropdown = context.querySelector('#pageDropdown');

    // Bind event listeners
    this.pageDropdown.addEventListener('change', this.jumpToPage.bind(this));
    this.fitParent.addEventListener('change', this.toggleCanvasFit.bind(this));
    this.prevBtn.addEventListener('click', this.prevPage.bind(this));
    this.nextBtn.addEventListener('click', this.nextPage.bind(this));
    this.zoomInBtn.addEventListener('click', this.zoomIn.bind(this));
    this.zoomOutBtn.addEventListener('click', this.zoomOut.bind(this));

    // Initialize
    this.toggleCanvasFit();
    this.onLoadCallbacks = []; // Array to store onLoad callbacks
  }

  async init() {
    // Load PDF.js worker
    pdfjsLib.GlobalWorkerOptions.workerSrc =
      'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.8.162/pdf.worker.min.js';

    // Initialize lazy loading using Intersection Observer
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.loadPDF();
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.1 } // Adjust threshold as needed
    );

    observer.observe(this.pdfContainer);
  }

  async loadPDF() {
    try {
      const loadingTask = pdfjsLib.getDocument({
        url: this.pdfURL,
        disableAutoFetch: false, // Allow PDF.js to fetch the entire file
        disableStream: false, // Enable streaming
        withCredentials: false, // Adjust based on your CORS setup
      });

      this.pdfDoc = await loadingTask.promise;
      this.totalPages = this.pdfDoc.numPages;

      // Populate the dropdown with page options
      this.populatePageDropdown();

      // Enable controls after PDF is loaded
      this.enableControls();

      // Render the initial page
      await this.renderPage(this.currentPage);

      // Enable lazy loading for subsequent pages
      this.enableLazyLoading();

      // Trigger onLoad callbacks
      this.onLoadCallbacks.forEach((callback) => callback());
    } catch (error) {
      console.error('Error loading PDF:', error);
    }
  }
  async renderPage(pageNum) {
    if (!this.pdfDoc || pageNum < 1 || pageNum > this.totalPages) return;

    const page = await this.pdfDoc.getPage(pageNum);
    const viewport = page.getViewport({ scale: this.currentScale });

    // Adjust canvas dimensions
    this.canvas.height = viewport.height;
    this.canvas.width = viewport.width;

    // Render the page
    const renderContext = {
      canvasContext: this.canvas.getContext('2d'),
      viewport: viewport,
    };
    await page.render(renderContext).promise;

    // Update controls
    this.updateControls();
  }

  onLoad(callback) {
    if (this.pdfDoc) {
      // If PDF is already loaded, call the callback immediately
      callback();
    } else {
      // Otherwise, add the callback to the queue
      this.onLoadCallbacks.push(callback);
    }
  }

  toggleCanvasFit() {
    if (this.fitParent.checked) {
      this.canvas.classList.add('w-100');
    } else {
      this.canvas.classList.remove('w-100');
      this.renderPage(this.currentPage);
    }
  }

  prevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.renderPage(this.currentPage);
    }
  }

  nextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.renderPage(this.currentPage);
    }
  }

  jumpToPage() {
    const selectedPage = parseInt(this.pageDropdown.value);
    if (selectedPage >= 1 && selectedPage <= this.totalPages) {
      this.currentPage = selectedPage;
      this.renderPage(this.currentPage);
    }
  }

  zoomIn() {
    if (this.currentScale < this.maxScale) {
      this.currentScale += 0.1;
      this.updateZoom();
    }
  }

  zoomOut() {
    if (this.currentScale > this.minScale) {
      this.currentScale -= 0.1;
      this.updateZoom();
    }
  }

  updateZoom() {
    const padding = Math.max(0, this.zoomLevel * 50);
    this.pdfContainer.style.paddingTop = `${padding}px`;
    this.canvas.style.transform = `scale(${this.currentScale})`;
    this.renderPage(this.currentPage); // Re-render page after zoom
  }

  populatePageDropdown() {
    this.pageDropdown.innerHTML = ''; // Clear existing options
    for (let i = 1; i <= this.totalPages; i++) {
      const option = document.createElement('option');
      option.value = i;
      option.text = `Page ${i}`;
      this.pageDropdown.appendChild(option);
    }
    this.pageDropdown.value = this.currentPage;
  }

  enableControls() {
    this.prevBtn.disabled = false;
    this.nextBtn.disabled = false;
    this.pageDropdown.disabled = false;
    this.zoomInBtn.disabled = false;
    this.zoomOutBtn.disabled = false;
  }

  updateControls() {
    this.prevBtn.disabled = this.currentPage === 1;
    this.nextBtn.disabled = this.currentPage === this.totalPages;
    this.pageDropdown.value = this.currentPage;
  }

  enableLazyLoading() {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && this.currentPage < this.totalPages) {
            this.nextPage();
          }
        });
      },
      { threshold: 0.5 } // Adjust threshold as needed
    );

    observer.observe(this.canvas);
  }
}

export default PDFViewer;
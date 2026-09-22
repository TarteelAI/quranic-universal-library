import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "tabBtn",
    "pageControls", "ayahControls", "wordControls", "scriptSettingsGroup",
    "mushafSelect", "pageSelect", "singlePageGroup", "batchPageGroup", "fromPageSelect", "toPageSelect",
    "ayahSurahSelect", "ayahSelect", "singleAyahGroup", "batchAyahGroup", "fromAyahSelect", "toAyahSelect",
    "wordSurahSelect", "wordAyahSelect", "wordPositionSelect", "singleWordGroup", "batchWordGroup", "fromWordSelect", "toWordSelect",
    "scriptSelect", "fontSizeSlider", "fontSizeBadge",
    "formatRadio", "transparentCheckbox", "retinaCheckbox",
    "previewFrame", "previewBox", "previewWrapper", "previewDimensionBadge",
    "singlePreviewContainer", "batchPreviewContainer", "batchPreviewList", "batchPreviewHeader", "batchOverflowNotice",
    "singleActionGroup", "batchActionGroup", "downloadBtn", "downloadBtnLabel", "downloadIcon", "downloadSpinner",
    "batchModal", "batchStatusLabel", "batchPercentLabel", "batchProgressBar", "batchDetailsLabel", "batchZipDownloadBtn"
  ];

  static values = {
    downloadUrl: String,
    verseWordsUrl: String,
    batchUrl: String,
    exportPageUrl: String,
    exportAyahUrl: String,
    exportWordUrl: String
  };

  connect() {
    this.activeType = "mushaf_page";
    this.activeMode = "single";
    this.activeFormat = "png";
    this.isTransparent = false;
    this.isRetina = true;
    this.fontSize = 50;

    this.debounceTimer = null;
    this.updateVisibleControls();
    this.refreshPreview();
  }

  switchTab(event) {
    const btn = event.currentTarget;
    const type = btn.dataset.type;
    if (this.activeType === type) return;

    this.activeType = type;

    // Update Tab Styles
    this.tabBtnTargets.forEach(targetBtn => {
      if (targetBtn === btn) {
        targetBtn.className = "px-5 py-2 rounded-lg text-sm font-semibold transition-all duration-200 bg-white text-gray-900 shadow-sm";
      } else {
        targetBtn.className = "px-5 py-2 rounded-lg text-sm font-semibold transition-all duration-200 text-gray-600 hover:text-gray-900";
      }
    });

    this.updateVisibleControls();
    this.handlePreviewRefresh();
  }

  switchMode(event) {
    this.activeMode = event.target.value;
    const isBatch = this.activeMode === "batch";

    if (this.hasSinglePageGroupTarget && this.hasBatchPageGroupTarget) {
      this.singlePageGroupTarget.classList.toggle("hidden", isBatch);
      this.batchPageGroupTarget.classList.toggle("hidden", !isBatch);
    }

    if (this.hasSingleAyahGroupTarget && this.hasBatchAyahGroupTarget) {
      this.singleAyahGroupTarget.classList.toggle("hidden", isBatch);
      this.batchAyahGroupTarget.classList.toggle("hidden", !isBatch);
    }

    if (this.hasSingleWordGroupTarget && this.hasBatchWordGroupTarget) {
      this.singleWordGroupTarget.classList.toggle("hidden", isBatch);
      this.batchWordGroupTarget.classList.toggle("hidden", !isBatch);
    }

    if (this.hasSingleActionGroupTarget && this.hasBatchActionGroupTarget) {
      this.singleActionGroupTarget.classList.toggle("hidden", isBatch);
      this.batchActionGroupTarget.classList.toggle("hidden", !isBatch);
    }

    if (this.hasSinglePreviewContainerTarget && this.hasBatchPreviewContainerTarget) {
      this.singlePreviewContainerTarget.classList.toggle("hidden", isBatch);
      this.batchPreviewContainerTarget.classList.toggle("hidden", !isBatch);
    }

    this.handlePreviewRefresh();
  }

  updateVisibleControls() {
    const isPage = this.activeType === "mushaf_page";
    const isAyah = this.activeType === "ayah";
    const isWord = this.activeType === "word";

    this.pageControlsTarget.classList.toggle("hidden", !isPage);
    this.ayahControlsTarget.classList.toggle("hidden", !isAyah);
    this.wordControlsTarget.classList.toggle("hidden", !isWord);

    // Script and Typography settings apply to Ayah & Word
    if (this.hasScriptSettingsGroupTarget) {
      this.scriptSettingsGroupTarget.classList.toggle("hidden", isPage);
    }
  }

  mushafChanged() {
    const selectedOption = this.mushafSelectTarget.selectedOptions[0];
    const pagesCount = parseInt(selectedOption?.dataset?.pages || 604, 10);

    // Populate Page Selectors
    this.populateSelectOptions(this.pageSelectTarget, 1, pagesCount);
    if (this.hasFromPageSelectTarget) this.populateSelectOptions(this.fromPageSelectTarget, 1, pagesCount, 1);
    if (this.hasToPageSelectTarget) this.populateSelectOptions(this.toPageSelectTarget, 1, pagesCount, Math.min(5, pagesCount));

    this.handlePreviewRefresh();
  }

  ayahSurahChanged() {
    const selectedOption = this.ayahSurahSelectTarget.selectedOptions[0];
    const versesCount = parseInt(selectedOption?.dataset?.verses || 7, 10);

    this.populateSelectOptions(this.ayahSelectTarget, 1, versesCount, 1);
    if (this.hasFromAyahSelectTarget) this.populateSelectOptions(this.fromAyahSelectTarget, 1, versesCount, 1);
    if (this.hasToAyahSelectTarget) this.populateSelectOptions(this.toAyahSelectTarget, 1, versesCount, Math.min(7, versesCount));

    this.handlePreviewRefresh();
  }

  wordSurahChanged() {
    const selectedOption = this.wordSurahSelectTarget.selectedOptions[0];
    const versesCount = parseInt(selectedOption?.dataset?.verses || 7, 10);

    this.populateSelectOptions(this.wordAyahSelectTarget, 1, versesCount, 1);
    this.wordAyahChanged();
  }

  async wordAyahChanged() {
    const surah = this.wordSurahSelectTarget.value;
    const ayah = this.wordAyahSelectTarget.value;

    try {
      const response = await fetch(`${this.verseWordsUrlValue}?chapter_id=${surah}&verse_number=${ayah}`);
      const data = await response.json();
      const wordsCount = data.words_count || 1;

      this.populateSelectOptions(this.wordPositionSelectTarget, 1, wordsCount, 1, (i) => `Word ${i}`);
      if (this.hasFromWordSelectTarget) this.populateSelectOptions(this.fromWordSelectTarget, 1, wordsCount, 1);
      if (this.hasToWordSelectTarget) this.populateSelectOptions(this.toWordSelectTarget, 1, wordsCount, Math.min(4, wordsCount));
    } catch (e) {
      console.warn("Failed to fetch verse words count:", e);
    }

    this.handlePreviewRefresh();
  }

  fromPageChanged() {
    const from = parseInt(this.fromPageSelectTarget.value, 10);
    const to = parseInt(this.toPageSelectTarget.value, 10);
    if (from > to) {
      this.toPageSelectTarget.value = from;
    }
    this.handlePreviewRefresh();
  }

  toPageChanged() {
    const from = parseInt(this.fromPageSelectTarget.value, 10);
    const to = parseInt(this.toPageSelectTarget.value, 10);
    if (to < from) {
      this.fromPageSelectTarget.value = to;
    }
    this.handlePreviewRefresh();
  }

  fromAyahChanged() {
    const from = parseInt(this.fromAyahSelectTarget.value, 10);
    const to = parseInt(this.toAyahSelectTarget.value, 10);
    if (from > to) {
      this.toAyahSelectTarget.value = from;
    }
    this.handlePreviewRefresh();
  }

  toAyahChanged() {
    const from = parseInt(this.fromAyahSelectTarget.value, 10);
    const to = parseInt(this.toAyahSelectTarget.value, 10);
    if (to < from) {
      this.fromAyahSelectTarget.value = to;
    }
    this.handlePreviewRefresh();
  }

  fromWordChanged() {
    const from = parseInt(this.fromWordSelectTarget.value, 10);
    const to = parseInt(this.toWordSelectTarget.value, 10);
    if (from > to) {
      this.toWordSelectTarget.value = from;
    }
    this.handlePreviewRefresh();
  }

  toWordChanged() {
    const from = parseInt(this.fromWordSelectTarget.value, 10);
    const to = parseInt(this.toWordSelectTarget.value, 10);
    if (to < from) {
      this.fromWordSelectTarget.value = to;
    }
    this.handlePreviewRefresh();
  }

  fontSizeSliderChanged(event) {
    this.fontSize = event.target.value;
    if (this.hasFontSizeBadgeTarget) {
      this.fontSizeBadgeTarget.textContent = `${this.fontSize}px`;
    }

    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.handlePreviewRefresh();
    }, 120);
  }

  formatChanged(event) {
    this.activeFormat = event.target.value;
    if (this.hasDownloadBtnLabelTarget) {
      this.downloadBtnLabelTarget.textContent = `Download ${this.activeFormat.toUpperCase()}`;
    }
  }

  transparentChanged(event) {
    this.isTransparent = event.target.checked;
    if (this.hasPreviewBoxTarget) {
      if (this.isTransparent) {
        this.previewBoxTarget.style.backgroundImage = "radial-gradient(#d1d5db 1px, transparent 1px)";
        this.previewBoxTarget.style.backgroundSize = "16px 16px";
      } else {
        this.previewBoxTarget.style.backgroundImage = "none";
      }
    }
    this.handlePreviewRefresh();
  }

  inputChanged() {
    this.handlePreviewRefresh();
  }

  handlePreviewRefresh() {
    if (this.activeMode === "batch") {
      this.refreshBatchPreviews();
    } else {
      this.refreshPreview();
    }
  }

  buildExportUrl() {
    const transparentParam = this.isTransparent ? "&transparent=true" : "";
    let url = "";

    switch (this.activeType) {
      case "mushaf_page": {
        const mushafId = this.mushafSelectTarget.value;
        const pageNum = this.pageSelectTarget.value;
        url = `${this.exportPageUrlValue}?page_number=${pageNum}&mushaf_id=${mushafId}${transparentParam}`;
        break;
      }
      case "ayah": {
        const surah = this.ayahSurahSelectTarget.value;
        const ayah = this.ayahSelectTarget.value;
        const script = this.scriptSelectTarget.value;
        url = `${this.exportAyahUrlValue}?ayah=${surah}:${ayah}&script=${script}&font_size=${this.fontSize}${transparentParam}`;
        break;
      }
      case "word": {
        const surah = this.wordSurahSelectTarget.value;
        const ayah = this.wordAyahSelectTarget.value;
        const word = this.wordPositionSelectTarget.value;
        const script = this.scriptSelectTarget.value;
        url = `${this.exportWordUrlValue}?word=${surah}:${ayah}:${word}&script=${script}&font_size=${this.fontSize}${transparentParam}`;
        break;
      }
    }

    return url;
  }

  refreshPreview() {
    const url = this.buildExportUrl();
    if (this.hasPreviewFrameTarget) {
      this.previewFrameTarget.src = url;
    }
  }

  refreshBatchPreviews() {
    if (!this.hasBatchPreviewListTarget) return;

    const transparentParam = this.isTransparent ? "&transparent=true" : "";
    const script = this.hasScriptSelectTarget ? this.scriptSelectTarget.value : "code_v1";
    let items = [];

    if (this.activeType === "mushaf_page") {
      const mushafId = this.mushafSelectTarget.value;
      const fromPage = parseInt(this.fromPageSelectTarget.value || 1, 10);
      const toPage = parseInt(this.toPageSelectTarget.value || 1, 10);
      const start = Math.min(fromPage, toPage);
      const end = Math.max(fromPage, toPage);

      for (let i = start; i <= end; i++) {
        items.push({
          label: `Page ${i}`,
          url: `${this.exportPageUrlValue}?page_number=${i}&mushaf_id=${mushafId}${transparentParam}`
        });
      }
    } else if (this.activeType === "ayah") {
      const surah = this.ayahSurahSelectTarget.value;
      const fromAyah = parseInt(this.fromAyahSelectTarget.value || 1, 10);
      const toAyah = parseInt(this.toAyahSelectTarget.value || 1, 10);
      const start = Math.min(fromAyah, toAyah);
      const end = Math.max(fromAyah, toAyah);

      for (let i = start; i <= end; i++) {
        items.push({
          label: `Ayah ${surah}:${i}`,
          url: `${this.exportAyahUrlValue}?ayah=${surah}:${i}&script=${script}&font_size=${this.fontSize}${transparentParam}`
        });
      }
    } else if (this.activeType === "word") {
      const surah = this.wordSurahSelectTarget.value;
      const ayah = this.wordAyahSelectTarget.value;
      const fromWord = parseInt(this.fromWordSelectTarget.value || 1, 10);
      const toWord = parseInt(this.toWordSelectTarget.value || 1, 10);
      const start = Math.min(fromWord, toWord);
      const end = Math.max(fromWord, toWord);

      for (let i = start; i <= end; i++) {
        items.push({
          label: `Word ${surah}:${ayah}:${i}`,
          url: `${this.exportWordUrlValue}?word=${surah}:${ayah}:${i}&script=${script}&font_size=${this.fontSize}${transparentParam}`
        });
      }
    }

    const total = items.length;
    const previewSubset = items.slice(0, 10);

    if (this.hasBatchPreviewHeaderTarget) {
      this.batchPreviewHeaderTarget.textContent = `Batch Range: ${total} Total Item${total === 1 ? '' : 's'}`;
    }

    if (this.hasPreviewDimensionBadgeTarget) {
      this.previewDimensionBadgeTarget.textContent = `${total} Items in Batch`;
    }

    // Build preview list HTML
    this.batchPreviewListTarget.innerHTML = "";

    previewSubset.forEach((item, index) => {
      const card = document.createElement("div");
      card.className = "bg-white border border-slate-200 rounded-xl p-3 shadow-sm hover:shadow transition-shadow space-y-2";
      
      const header = document.createElement("div");
      header.className = "flex justify-between items-center text-xs font-bold text-slate-700 pb-1 border-b border-slate-100";
      header.innerHTML = `<span>#${index + 1} — ${item.label}</span><span class="text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100 font-mono text-[10px]">Preview</span>`;
      
      const iframe = document.createElement("iframe");
      iframe.src = item.url;
      iframe.className = "w-full border-0 min-h-[140px] bg-transparent";
      iframe.onload = () => {
        try {
          const doc = iframe.contentDocument || iframe.contentWindow.document;
          if (doc) {
            const el = doc.querySelector("#content") || doc.body;
            if (el) {
              const h = el.scrollHeight || el.offsetHeight;
              iframe.style.height = `${Math.max(h + 20, 140)}px`;
            }
          }
        } catch (_) {}
      };

      card.appendChild(header);
      card.appendChild(iframe);
      this.batchPreviewListTarget.appendChild(card);
    });

    if (this.hasBatchOverflowNoticeTarget) {
      if (total > 10) {
        this.batchOverflowNoticeTarget.classList.remove("hidden");
        this.batchOverflowNoticeTarget.textContent = `📦 +${total - 10} more items in this range will be rendered and packaged into the downloaded ZIP archive.`;
      } else {
        this.batchOverflowNoticeTarget.classList.add("hidden");
      }
    }
  }

  frameLoaded(event) {
    try {
      const iframe = event?.target || this.previewFrameTarget;
      const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
      if (!iframeDoc) return;

      const contentElem = iframeDoc.querySelector("#content") || iframeDoc.body;
      if (contentElem) {
        const width = contentElem.scrollWidth || contentElem.offsetWidth;
        const height = contentElem.scrollHeight || contentElem.offsetHeight;

        iframe.style.height = `${Math.max(height + 25, 420)}px`;

        if (this.hasPreviewDimensionBadgeTarget && this.activeMode === "single") {
          this.previewDimensionBadgeTarget.textContent = `${width} × ${height} px`;
        }
      }
    } catch (e) {
      // Cross-origin fallback
    }
  }

  async downloadSingleImage() {
    const btn = this.downloadBtnTarget;
    const originalLabel = this.downloadBtnLabelTarget.textContent;

    try {
      if (this.hasDownloadIconTarget) this.downloadIconTarget.classList.add("hidden");
      if (this.hasDownloadSpinnerTarget) this.downloadSpinnerTarget.classList.remove("hidden");
      this.downloadBtnLabelTarget.textContent = "Downloading...";
      btn.disabled = true;

      const filename = this.generateFilename();
      const isRetina = this.hasRetinaCheckboxTarget ? this.retinaCheckboxTarget.checked : true;
      const scale = isRetina ? 2 : 1;

      const params = new URLSearchParams({
        export_type: this.activeType,
        format: this.activeFormat,
        scale: scale,
        transparent: this.isTransparent,
        filename: filename
      });

      if (this.activeType === "mushaf_page") {
        params.append("mushaf_id", this.mushafSelectTarget.value);
        params.append("page_number", this.pageSelectTarget.value);
      } else if (this.activeType === "ayah") {
        const surah = this.ayahSurahSelectTarget.value;
        const ayah = this.ayahSelectTarget.value;
        params.append("ayah", `${surah}:${ayah}`);
        params.append("script", this.scriptSelectTarget.value);
        params.append("font_size", this.fontSize);
      } else if (this.activeType === "word") {
        const surah = this.wordSurahSelectTarget.value;
        const ayah = this.wordAyahSelectTarget.value;
        const word = this.wordPositionSelectTarget.value;
        params.append("word", `${surah}:${ayah}:${word}`);
        params.append("script", this.scriptSelectTarget.value);
        params.append("font_size", this.fontSize);
      }

      const downloadEndpoint = `${this.downloadUrlValue}?${params.toString()}`;

      // Fetch rendered image
      const response = await fetch(downloadEndpoint);
      if (!response.ok) {
        throw new Error(`Server returned status ${response.status}`);
      }

      const blob = await response.blob();
      const blobUrl = window.URL.createObjectURL(blob);

      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = `${filename}.${this.activeFormat}`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(blobUrl);

    } catch (error) {
      console.error("Image export failed:", error);
      alert(`Export failed: ${error.message || error}`);
    } finally {
      if (this.hasDownloadIconTarget) this.downloadIconTarget.classList.remove("hidden");
      if (this.hasDownloadSpinnerTarget) this.downloadSpinnerTarget.classList.add("hidden");
      this.downloadBtnLabelTarget.textContent = originalLabel;
      btn.disabled = false;
    }
  }

  generateFilename() {
    switch (this.activeType) {
      case "mushaf_page": {
        const mushafId = this.mushafSelectTarget.value;
        const pageNum = this.pageSelectTarget.value.toString().padStart(3, "0");
        return `mushaf_${mushafId}_page_${pageNum}`;
      }
      case "ayah": {
        const surah = this.ayahSurahSelectTarget.value.toString().padStart(3, "0");
        const ayah = this.ayahSelectTarget.value.toString().padStart(3, "0");
        const script = this.scriptSelectTarget.value;
        return `ayah_${surah}_${ayah}_${script}`;
      }
      case "word": {
        const surah = this.wordSurahSelectTarget.value.toString().padStart(3, "0");
        const ayah = this.wordAyahSelectTarget.value.toString().padStart(3, "0");
        const word = this.wordPositionSelectTarget.value.toString().padStart(3, "0");
        const script = this.scriptSelectTarget.value;
        return `word_${surah}_${ayah}_${word}_${script}`;
      }
    }
  }

  async startBatchExport() {
    this.batchModalTarget.classList.remove("hidden");
    if (this.hasBatchZipDownloadBtnTarget) {
      this.batchZipDownloadBtnTarget.classList.add("hidden");
    }

    const isRetina = this.hasRetinaCheckboxTarget ? this.retinaCheckboxTarget.checked : true;
    const scale = isRetina ? 2 : 1;

    let params = new URLSearchParams({
      export_type: this.activeType,
      format: this.activeFormat,
      scale: scale,
      transparent: this.isTransparent,
      script: this.hasScriptSelectTarget ? this.scriptSelectTarget.value : "code_v1",
      font_size: this.fontSize
    });

    let defaultZipName = `quran_export_${this.activeType}_batch.zip`;
    let itemCount = 1;

    if (this.activeType === "mushaf_page") {
      const fromP = parseInt(this.fromPageSelectTarget.value || 1, 10);
      const toP = parseInt(this.toPageSelectTarget.value || 1, 10);
      itemCount = Math.abs(toP - fromP) + 1;
      params.append("mushaf_id", this.mushafSelectTarget.value);
      params.append("from_page", fromP);
      params.append("to_page", toP);
      defaultZipName = `mushaf_${this.mushafSelectTarget.value}_pages_${fromP}_to_${toP}.zip`;
    } else if (this.activeType === "ayah") {
      const fromA = parseInt(this.fromAyahSelectTarget.value || 1, 10);
      const toA = parseInt(this.toAyahSelectTarget.value || 1, 10);
      itemCount = Math.abs(toA - fromA) + 1;
      params.append("chapter_id", this.ayahSurahSelectTarget.value);
      params.append("from_ayah", fromA);
      params.append("to_ayah", toA);
      defaultZipName = `surah_${this.ayahSurahSelectTarget.value}_ayahs_${fromA}_to_${toA}.zip`;
    } else if (this.activeType === "word") {
      const fromW = parseInt(this.fromWordSelectTarget.value || 1, 10);
      const toW = parseInt(this.toWordSelectTarget.value || 1, 10);
      itemCount = Math.abs(toW - fromW) + 1;
      params.append("chapter_id", this.wordSurahSelectTarget.value);
      params.append("verse_num", this.wordAyahSelectTarget.value);
      params.append("from_word", fromW);
      params.append("to_word", toW);
      defaultZipName = `surah_${this.wordSurahSelectTarget.value}_ayah_${this.wordAyahSelectTarget.value}_words.zip`;
    }

    // Dynamic progress bar calculation
    let currentPercent = 10;
    this.batchProgressBarTarget.style.width = "10%";
    this.batchPercentLabelTarget.textContent = "10%";
    this.batchStatusLabelTarget.textContent = `Starting batch export (${itemCount} items)...`;
    this.batchDetailsLabelTarget.textContent = `Preparing high-resolution ${this.activeFormat.toUpperCase()} images...`;

    const startTime = Date.now();
    const estimatedTotalMs = Math.max(itemCount * 450, 1200);

    const progressInterval = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const calculatedPercent = Math.min(Math.floor((elapsed / estimatedTotalMs) * 85) + 10, 95);
      const currentItemNum = Math.min(Math.floor((calculatedPercent / 90) * itemCount) + 1, itemCount);

      currentPercent = calculatedPercent;
      this.batchProgressBarTarget.style.width = `${currentPercent}%`;
      this.batchPercentLabelTarget.textContent = `${currentPercent}%`;

      if (currentPercent < 90) {
        this.batchStatusLabelTarget.textContent = `Rendering image ${currentItemNum} of ${itemCount}...`;
        this.batchDetailsLabelTarget.textContent = `Processing glyph ligatures and vector frames (${currentPercent}%)...`;
      } else {
        this.batchStatusLabelTarget.textContent = `Packaging into ZIP archive...`;
        this.batchDetailsLabelTarget.textContent = `Compressing ${itemCount} images into ${defaultZipName}...`;
      }
    }, 150);

    try {
      const response = await fetch(this.batchUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: params.toString()
      });

      clearInterval(progressInterval);

      if (!response.ok) {
        let errText = "Failed to generate batch archive";
        try {
          const errJson = await response.json();
          errText = errJson.error || errText;
        } catch (_) {
          errText = await response.text();
        }
        throw new Error(errText);
      }

      this.batchProgressBarTarget.style.width = "100%";
      this.batchPercentLabelTarget.textContent = "100%";
      this.batchStatusLabelTarget.textContent = `✓ Batch Export Complete (${itemCount} items)!`;
      this.batchDetailsLabelTarget.textContent = `Your ZIP archive has downloaded.`;

      const blob = await response.blob();
      const blobUrl = window.URL.createObjectURL(blob);

      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = defaultZipName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      if (this.hasBatchZipDownloadBtnTarget) {
        this.batchZipDownloadBtnTarget.classList.remove("hidden");
        this.batchZipDownloadBtnTarget.textContent = "Download ZIP Again";
        this.batchZipDownloadBtnTarget.onclick = () => {
          const reLink = document.createElement("a");
          reLink.href = blobUrl;
          reLink.download = defaultZipName;
          document.body.appendChild(reLink);
          reLink.click();
          document.body.removeChild(reLink);
        };
      }

    } catch (e) {
      clearInterval(progressInterval);
      this.batchStatusLabelTarget.textContent = `Batch Export Failed`;
      this.batchDetailsLabelTarget.textContent = e.message || "An unexpected error occurred.";
      this.batchProgressBarTarget.style.backgroundColor = "#ef4444";
    }
  }

  closeBatchModal() {
    this.batchModalTarget.classList.add("hidden");
  }

  cancelBatch() {
    this.closeBatchModal();
  }

  populateSelectOptions(selectElem, from, to, selectedValue = null, labelFn = (i) => i) {
    if (!selectElem) return;
    selectElem.innerHTML = "";
    for (let i = from; i <= to; i++) {
      const option = document.createElement("option");
      option.value = i;
      option.textContent = labelFn(i);
      if (selectedValue && i === parseInt(selectedValue, 10)) {
        option.selected = true;
      }
      selectElem.appendChild(option);
    }
  }
}

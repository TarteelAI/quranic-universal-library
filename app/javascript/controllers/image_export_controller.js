import { Controller } from "@hotwired/stimulus";
import { buildExportUrl, buildBatchItems, generateFilename } from "../utils/image_export/items";
import { renderUrlToBlob } from "../utils/image_export/render";
import JSZip from "jszip";

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
    "singleActionGroup", "batchActionGroup", "downloadBtn", "downloadBtnLabel", "batchBtnLabel", "downloadIcon", "downloadSpinner",
    "batchModal", "batchStatusLabel", "batchPercentLabel", "batchProgressBar", "batchDetailsLabel", "batchCancelBtn", "batchCloseBtn"
  ];

  static values = {
    downloadUrl: String,
    verseWordsUrl: String,
    batchUrl: String,
    exportPageUrl: String,
    exportAyahUrl: String,
    exportWordUrl: String,
    signedIn: Boolean,
    signInUrl: String
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
    this.updateDownloadBtnLabel();
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
    this.updateDownloadBtnLabel();
  }

  updateDownloadBtnLabel() {
    if (this.hasDownloadBtnLabelTarget) {
      const fmt = this.activeFormat.toUpperCase();
      if (!this.signedInValue) {
        this.downloadBtnLabelTarget.textContent = `Login to Download ${fmt}`;
      } else {
        this.downloadBtnLabelTarget.textContent = `Download ${fmt}`;
      }
    }

    if (this.hasBatchBtnLabelTarget) {
      this.batchBtnLabelTarget.textContent = this.signedInValue ? "Generate Batch ZIP" : "Login to Export ZIP";
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

  // Snapshot of the form values consumed by the URL helpers in utils/image_export/items.js
  exportState() {
    const val = (name) => (this[`has${name}Target`] ? this[`${name[0].toLowerCase()}${name.slice(1)}Target`].value : undefined);
    const int = (name, fallback = 1) => parseInt(val(name) || fallback, 10);

    return {
      type: this.activeType,
      urls: { page: this.exportPageUrlValue, ayah: this.exportAyahUrlValue, word: this.exportWordUrlValue },
      transparent: this.isTransparent,
      fontSize: this.fontSize,
      script: val("ScriptSelect") || "code_v1",
      mushafId: val("MushafSelect"),
      page: val("PageSelect"),
      fromPage: int("FromPageSelect"),
      toPage: int("ToPageSelect"),
      ayahSurah: val("AyahSurahSelect"),
      ayah: val("AyahSelect"),
      fromAyah: int("FromAyahSelect"),
      toAyah: int("ToAyahSelect"),
      wordSurah: val("WordSurahSelect"),
      wordAyah: val("WordAyahSelect"),
      word: val("WordPositionSelect"),
      fromWord: int("FromWordSelect"),
      toWord: int("ToWordSelect")
    };
  }

  buildExportUrl() {
    return buildExportUrl(this.exportState());
  }

  refreshPreview() {
    const url = this.buildExportUrl();
    if (this.hasPreviewFrameTarget) {
      this.previewFrameTarget.src = url;
    }
  }

  refreshBatchPreviews() {
    if (!this.hasBatchPreviewListTarget) return;

    const items = buildBatchItems(this.exportState());


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
      header.innerHTML = `<span>#${index + 1} — ${item.shortLabel}</span><span class="text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100 font-mono text-[10px]">Preview</span>`;
      
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

  // Browsing and previewing is public; downloading requires an account.
  redirectToSignIn() {
    window.location.href = this.signInUrlValue;
  }

  async downloadSingleImage() {
    if (!this.signedInValue) return this.redirectToSignIn();

    const btn = this.downloadBtnTarget;

    try {
      if (this.hasDownloadIconTarget) this.downloadIconTarget.classList.add("hidden");
      if (this.hasDownloadSpinnerTarget) this.downloadSpinnerTarget.classList.remove("hidden");
      this.downloadBtnLabelTarget.textContent = "Rendering...";
      btn.disabled = true;

      const filename = this.generateFilename();
      const isRetina = this.hasRetinaCheckboxTarget ? this.retinaCheckboxTarget.checked : true;
      const scale = isRetina ? 2 : 1;
      const exportUrl = this.buildExportUrl();

      const blob = await renderUrlToBlob(exportUrl, {
        format: this.activeFormat,
        scale: scale,
        transparent: this.isTransparent
      });

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
      this.updateDownloadBtnLabel();
      btn.disabled = false;
    }
  }

  generateFilename() {
    return generateFilename(this.exportState());
  }

  getBatchItems() {
    return buildBatchItems(this.exportState());
  }

  async startBatchExport() {
    if (!this.signedInValue) return this.redirectToSignIn();

    // Abort any existing batch run
    if (this.batchAbortController) {
      this.batchAbortController.abort();
    }
    this.batchAbortController = new AbortController();
    this.isBatchCancelled = false;

    this.batchModalTarget.classList.remove("hidden");
    if (this.hasBatchCancelBtnTarget) {
      this.batchCancelBtnTarget.classList.remove("hidden");
    }
    if (this.hasBatchCloseBtnTarget) {
      this.batchCloseBtnTarget.classList.add("hidden");
    }

    const isRetina = this.hasRetinaCheckboxTarget ? this.retinaCheckboxTarget.checked : true;
    const scale = isRetina ? 2 : 1;

    const items = this.getBatchItems();
    const total = items.length;

    if (total === 0) {
      alert("No items selected to export.");
      this.closeBatchModal();
      return;
    }

    let defaultZipName = `quran_export_${this.activeType}_batch.zip`;
    if (this.activeType === "mushaf_page") {
      const fromP = parseInt(this.fromPageSelectTarget.value || 1, 10);
      const toP = parseInt(this.toPageSelectTarget.value || 1, 10);
      defaultZipName = `mushaf_${this.mushafSelectTarget.value}_pages_${Math.min(fromP, toP)}_to_${Math.max(fromP, toP)}.zip`;
    } else if (this.activeType === "ayah") {
      const fromA = parseInt(this.fromAyahSelectTarget.value || 1, 10);
      const toA = parseInt(this.toAyahSelectTarget.value || 1, 10);
      defaultZipName = `surah_${this.ayahSurahSelectTarget.value}_ayahs_${Math.min(fromA, toA)}_to_${Math.max(fromA, toA)}.zip`;
    } else if (this.activeType === "word") {
      defaultZipName = `surah_${this.wordSurahSelectTarget.value}_ayah_${this.wordAyahSelectTarget.value}_words.zip`;
    }

    this.batchProgressBarTarget.style.width = "0%";
    this.batchPercentLabelTarget.textContent = "0%";
    this.batchProgressBarTarget.style.backgroundColor = "";
    this.batchStatusLabelTarget.textContent = `Starting batch export (${total} items)...`;
    this.batchDetailsLabelTarget.textContent = `Rendering high-resolution ${this.activeFormat.toUpperCase()} images in your browser...`;

    const zip = new JSZip();

    try {
      for (let i = 0; i < total; i++) {
        if (this.isBatchCancelled || this.batchAbortController.signal.aborted) {
          return;
        }

        const item = items[i];
        const currentItemNum = i + 1;
        const percent = Math.floor((i / total) * 90);

        this.batchProgressBarTarget.style.width = `${percent}%`;
        this.batchPercentLabelTarget.textContent = `${percent}%`;
        this.batchStatusLabelTarget.textContent = `Rendering image ${currentItemNum} of ${total}...`;
        this.batchDetailsLabelTarget.textContent = `${item.label} (${percent}%)...`;

        const blob = await renderUrlToBlob(item.url, {
          format: this.activeFormat,
          scale: scale,
          transparent: this.isTransparent,
          signal: this.batchAbortController.signal
        });

        if (this.isBatchCancelled || this.batchAbortController.signal.aborted) {
          return;
        }

        zip.file(`${item.filename}.${this.activeFormat}`, blob);
      }

      if (this.isBatchCancelled || this.batchAbortController.signal.aborted) return;

      this.batchStatusLabelTarget.textContent = `Packaging ${total} images into ZIP archive...`;
      this.batchDetailsLabelTarget.textContent = `Generating ${defaultZipName}...`;
      this.batchProgressBarTarget.style.width = "92%";
      this.batchPercentLabelTarget.textContent = "92%";

      const zipBlob = await zip.generateAsync({ type: "blob" }, (metadata) => {
        if (this.isBatchCancelled || this.batchAbortController.signal.aborted) return;
        const compPercent = Math.min(90 + Math.floor(metadata.percent / 10), 99);
        this.batchProgressBarTarget.style.width = `${compPercent}%`;
        this.batchPercentLabelTarget.textContent = `${compPercent}%`;
      });

      if (this.isBatchCancelled || this.batchAbortController.signal.aborted) return;

      this.batchProgressBarTarget.style.width = "100%";
      this.batchPercentLabelTarget.textContent = "100%";
      this.batchStatusLabelTarget.textContent = `✓ Batch Export Complete (${total} items)!`;
      this.batchDetailsLabelTarget.textContent = `Your ZIP archive has been generated and downloaded.`;

      const blobUrl = window.URL.createObjectURL(zipBlob);
      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = defaultZipName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      setTimeout(() => window.URL.revokeObjectURL(blobUrl), 10000);

      if (this.hasBatchCancelBtnTarget) {
        this.batchCancelBtnTarget.classList.add("hidden");
      }
      if (this.hasBatchCloseBtnTarget) {
        this.batchCloseBtnTarget.classList.remove("hidden");
      }

    } catch (e) {
      if (this.isBatchCancelled || e.name === "AbortError" || this.batchAbortController?.signal?.aborted) {
        return;
      }
      console.error("Batch export error:", e);
      this.batchStatusLabelTarget.textContent = `Batch Export Failed`;
      this.batchDetailsLabelTarget.textContent = e.message || "An unexpected error occurred.";
      this.batchProgressBarTarget.style.backgroundColor = "#ef4444";
      if (this.hasBatchCancelBtnTarget) {
        this.batchCancelBtnTarget.classList.add("hidden");
      }
      if (this.hasBatchCloseBtnTarget) {
        this.batchCloseBtnTarget.classList.remove("hidden");
      }
    }
  }

  closeBatchModal() {
    this.cancelBatch();
  }

  cancelBatch() {
    this.isBatchCancelled = true;
    if (this.batchAbortController) {
      this.batchAbortController.abort();
    }
    // Remove any lingering rendering iframes immediately
    document.querySelectorAll("iframe[data-export-render]").forEach((el) => {
      try {
        el.src = "about:blank";
        el.remove();
      } catch (_) {}
    });
    this.batchModalTarget.classList.add("hidden");
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

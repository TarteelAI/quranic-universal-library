import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["code", "copyButton", "editor", "preview"];
  static values = {
    playground: Boolean,
    language: String
  };

  connect() {
    this.initialCode = this.currentCode();
    this.applyEditorFontFallbacks();
    if (this.playgroundValue && this.hasEditorTarget && this.hasPreviewTarget) {
      this.run();
    }
  }

  copy(event) {
    const sourceButton = event?.currentTarget || this.copyButtonTarget;
    this.copyToClipboard(this.currentCode())
      .then(() => this.flashButton(sourceButton, "Copied"))
      .catch(() => this.flashButton(sourceButton, "Copy failed"));
  }

  run(event) {
    event?.preventDefault();
    if (!this.playgroundValue || !this.hasEditorTarget || !this.hasPreviewTarget) return;

    const language = (this.languageValue || "javascript").toLowerCase();
    if (language !== "javascript") {
      this.previewTarget.srcdoc = this.unsupportedPreview(language);
      return;
    }

    const safeCode = this.editorTarget.value.replace(/<\/script/gi, "<\\/script");
    this.previewTarget.srcdoc = this.javascriptPreview(safeCode, this.stylesheetLinksMarkup());
  }

  reset(event) {
    event?.preventDefault();
    if (!this.playgroundValue || !this.hasEditorTarget) return;

    this.editorTarget.value = this.initialCode || "";
    this.run();
  }

  currentCode() {
    if (this.hasEditorTarget) return this.editorTarget.value;
    if (this.hasCodeTarget) return this.codeTarget.textContent || "";
    return "";
  }

  applyEditorFontFallbacks() {
    if (!this.hasEditorTarget) return;

    // Keep monospace behavior, but add Arabic-capable fallbacks so Quranic glyphs don't render as boxes.
    this.editorTarget.style.fontFamily = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', 'Noto Naskh Arabic', 'Amiri Quran', 'Scheherazade New', 'Geeza Pro', 'Arial Unicode MS', monospace";
    this.editorTarget.style.fontFeatureSettings = "\"liga\" 1, \"calt\" 1";
  }

  flashButton(button, message) {
    if (!button) return;

    const originalLabel = button.dataset.originalLabel || button.textContent;
    button.dataset.originalLabel = originalLabel;
    button.textContent = message;

    if (button._docsCodeTimeout) clearTimeout(button._docsCodeTimeout);
    button._docsCodeTimeout = setTimeout(() => {
      button.textContent = originalLabel;
    }, 1200);
  }

  copyToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise((resolve, reject) => {
      const element = document.createElement("textarea");
      element.value = text;
      element.style.position = "fixed";
      element.style.opacity = "0";
      document.body.appendChild(element);
      element.select();

      try {
        document.execCommand("copy");
        resolve();
      } catch (error) {
        reject(error);
      } finally {
        element.remove();
      }
    });
  }

  javascriptPreview(code, stylesheetLinksMarkup = "") {
    return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    ${stylesheetLinksMarkup}
    <style>
      @import url("https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;700&family=Amiri+Quran&display=swap");

      :root {
        --docs-arabic-font: "Noto Naskh Arabic", "Amiri Quran", "Scheherazade New", "Geeza Pro", "Arial Unicode MS", serif;
      }

      body {
        margin: 0;
        padding: 16px;
        font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
        color: #0f172a;
        background: #ffffff;
      }
      [dir="rtl"], .docs-arabic {
        font-family: var(--docs-arabic-font) !important;
        text-rendering: optimizeLegibility;
      }
      .docs-preview-error {
        margin-top: 12px;
        border-radius: 8px;
        border: 1px solid #fecaca;
        background: #fff1f2;
        color: #9f1239;
        padding: 12px;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        white-space: pre-wrap;
      }
    </style>
  </head>
  <body>
    <div id="app"></div>
    <script>
      const showError = (message) => {
        const error = document.createElement("pre");
        error.className = "docs-preview-error";
        error.textContent = String(message);
        document.body.appendChild(error);
      };

      window.addEventListener("error", (event) => {
        showError(event.error?.stack || event.message || "Preview error");
      });

      window.addEventListener("unhandledrejection", (event) => {
        showError(event.reason?.stack || event.reason || "Unhandled promise rejection");
      });

      try {
        ${code}
      } catch (error) {
        showError(error.stack || error.message || error);
      }
    </script>
  </body>
</html>`;
  }

  stylesheetLinksMarkup() {
    const links = Array.from(document.querySelectorAll('link[rel="stylesheet"][href]'))
      .map((link) => link.getAttribute("href"))
      .filter(Boolean)
      .map((href) => `<link rel="stylesheet" href="${href}">`)
      .join("");

    return links;
  }

  unsupportedPreview(language) {
    return `<!doctype html><html><body><p>Preview for "${language}" is not supported yet.</p></body></html>`;
  }
}

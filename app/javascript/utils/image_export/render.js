import domtoimage from "dom-to-image-more";
import { buildInlinedFontCss } from "./fonts";

// Loads `url` in a hidden iframe and renders its #content element to an image Blob.
export function renderUrlToBlob(url, { format = "png", scale = 2, transparent = false, signal = null } = {}) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      return reject(new DOMException("Aborted", "AbortError"));
    }

    const iframe = document.createElement("iframe");
    iframe.dataset.exportRender = "true";
    iframe.style.position = "fixed";
    iframe.style.left = "-9999px";
    iframe.style.top = "-9999px";
    iframe.style.width = "1200px";
    iframe.style.height = "1600px";
    iframe.style.opacity = "0";
    iframe.style.pointerEvents = "none";
    iframe.style.border = "none";
    iframe.style.zIndex = "-1";

    let hasCleanedUp = false;
    let timeoutTimer = null;

    const cleanup = () => {
      if (hasCleanedUp) return;
      hasCleanedUp = true;
      if (timeoutTimer) clearTimeout(timeoutTimer);
      if (signal) signal.removeEventListener("abort", onAbort);
      try {
        iframe.onload = null;
        iframe.onerror = null;
        iframe.src = "about:blank";
        if (iframe.parentNode) {
          iframe.parentNode.removeChild(iframe);
        }
      } catch (_) {}
    };

    const onAbort = () => {
      cleanup();
      reject(new DOMException("Aborted", "AbortError"));
    };

    if (signal) {
      signal.addEventListener("abort", onAbort, { once: true });
    }

    timeoutTimer = setTimeout(() => {
      cleanup();
      reject(new Error("Timeout loading export page for rendering."));
    }, 25000);

    iframe.onload = async () => {
      if (hasCleanedUp) return;
      if (signal?.aborted) {
        onAbort();
        return;
      }

      try {
        const doc = iframe.contentDocument || iframe.contentWindow.document;
        if (!doc) {
          throw new Error("Unable to access iframe document.");
        }

        // Wait for fonts to load and settle (essential for Arabic Quran ligatures)
        if (doc.fonts && doc.fonts.ready) {
          await doc.fonts.ready;
        }
        if (signal?.aborted) {
          onAbort();
          return;
        }

        await new Promise((r) => setTimeout(r, 120));
        if (signal?.aborted) {
          onAbort();
          return;
        }

        const contentElem = doc.querySelector("#content") || doc.body;

        // Inline required fonts as base64 so SVG image renderer decodes custom Quran fonts
        const inlinedFontCss = await buildInlinedFontCss(doc, contentElem);

        const width = contentElem.offsetWidth || contentElem.scrollWidth || 1000;
        const height = contentElem.offsetHeight || contentElem.scrollHeight || 1400;

        const options = {
          scale: scale,
          bgcolor: transparent ? undefined : "#ffffff",
          width: width,
          height: height,
          disableEmbedFonts: true,
          adjustClonedNode: (original, clone, after) => {
            if (after && original === contentElem && inlinedFontCss) {
              const styleNode = (clone.ownerDocument || document).createElement("style");
              styleNode.setAttribute("type", "text/css");
              styleNode.textContent = inlinedFontCss;
              clone.appendChild(styleNode);
            }
          }
        };

        const canvas = await domtoimage.toCanvas(contentElem, options);
        if (signal?.aborted) {
          onAbort();
          return;
        }

        const mimeType = format === "webp" ? "image/webp" : "image/png";

        canvas.toBlob((blob) => {
          if (signal?.aborted) {
            onAbort();
            return;
          }
          cleanup();
          if (blob) {
            resolve(blob);
          } else {
            // Fallback to PNG if WebP canvas export is unsupported by the browser
            canvas.toBlob((pngBlob) => {
              if (pngBlob) {
                resolve(pngBlob);
              } else {
                reject(new Error("Canvas toBlob failed to produce an image."));
              }
            }, "image/png");
          }
        }, mimeType, 0.95);

      } catch (err) {
        cleanup();
        reject(err);
      }
    };

    iframe.onerror = (err) => {
      cleanup();
      reject(new Error(`Failed to load export iframe: ${err?.message || err}`));
    };

    iframe.src = url;
    document.body.appendChild(iframe);
  });
}

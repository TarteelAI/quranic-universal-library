// Inlines the @font-face fonts used by an export page as base64 data URIs so
// the SVG-based image renderer can decode custom Quran fonts.
const fontDataUriCache = new Map();

export async function buildInlinedFontCss(doc, contentElem) {
  try {
    const win = doc.defaultView || window;
    const usedFamilies = new Set();
    const allElems = [contentElem, ...contentElem.querySelectorAll("*")];

    for (const el of allElems) {
      const ff = win.getComputedStyle(el).fontFamily;
      if (ff) {
        ff.split(",").forEach((f) => {
          const clean = f.replace(/['"\\]/g, "").trim().toLowerCase();
          if (clean) usedFamilies.add(clean);
        });
      }
      const beforeFF = win.getComputedStyle(el, "::before").fontFamily;
      if (beforeFF) {
        beforeFF.split(",").forEach((f) => {
          const clean = f.replace(/['"\\]/g, "").trim().toLowerCase();
          if (clean) usedFamilies.add(clean);
        });
      }
    }

    // Collect @font-face rules from all accessible stylesheets and <style> tags
    const fontRulesToProcess = [];
    const paletteRules = [];

    const processRule = (family, weight, style, srcText) => {
      const famLower = family.toLowerCase();
      if (usedFamilies.has(famLower) || famLower.match(/^p\d+-(v1|v2|v4)/i)) {
        if (!fontRulesToProcess.some((r) => r.family.toLowerCase() === famLower)) {
          fontRulesToProcess.push({ family, weight, style, srcText });
        }
      }
    };

    // 1. Check doc.styleSheets
    for (const sheet of Array.from(doc.styleSheets || [])) {
      try {
        const rules = sheet.cssRules || [];
        for (const rule of Array.from(rules)) {
          if (rule.type === CSSRule.FONT_FACE_RULE) {
            const family = (rule.style.getPropertyValue("font-family") || "").replace(/['"\\]/g, "").trim();
            if (family) {
              processRule(
                family,
                rule.style.getPropertyValue("font-weight"),
                rule.style.getPropertyValue("font-style"),
                rule.style.getPropertyValue("src") || rule.cssText
              );
            }
          } else if (rule.cssText && rule.cssText.includes("@font-palette-values")) {
            paletteRules.push(rule.cssText);
          }
        }
      } catch (_) {}
    }

    // 2. Also check <style> elements directly in doc (head and body)
    doc.querySelectorAll("style").forEach((styleEl) => {
      const text = styleEl.textContent || "";
      const fontFaceRegex = /@font-face\s*\{([^}]+)\}/gi;
      let m;
      while ((m = fontFaceRegex.exec(text)) !== null) {
        const body = m[1];
        const famMatch = body.match(/font-family\s*:\s*['"]?([^'";}]+)['"]?/i);
        if (!famMatch) continue;
        const family = famMatch[1].replace(/['"\\]/g, "").trim();
        if (family) {
          const weightMatch = body.match(/font-weight\s*:\s*([^;]+)/i);
          const styleMatch = body.match(/font-style\s*:\s*([^;]+)/i);
          processRule(
            family,
            weightMatch ? weightMatch[1].trim() : "",
            styleMatch ? styleMatch[1].trim() : "",
            body
          );
        }
      }
      const paletteRegex = /@font-palette-values\s+[^{]+\{[^}]+\}/gi;
      let pm;
      while ((pm = paletteRegex.exec(text)) !== null) {
        paletteRules.push(pm[0]);
      }
    });

    if (fontRulesToProcess.length === 0) {
      return paletteRules.join("\n");
    }

    // Fetch and encode each required font into Base64
    const inlinedRules = await Promise.all(
      fontRulesToProcess.map(async (ruleObj) => {
        try {
          const urls = Array.from(ruleObj.srcText.matchAll(/url\(\s*['"]?([^'")]+)['"]?\s*\)/gi)).map((m) => m[1]);
          if (urls.length === 0) return "";

          // Prioritize woff2 > woff > ttf
          const chosenUrl = urls.find((u) => u.includes(".woff2")) ||
                            urls.find((u) => u.includes(".woff")) ||
                            urls.find((u) => u.includes(".ttf")) ||
                            urls[0];

          let dataUri = chosenUrl;
          if (!chosenUrl.startsWith("data:")) {
            const resolvedUrl = new URL(chosenUrl, win.location.href).href;
            dataUri = await fetchFontAsBase64(resolvedUrl);
          }

          let fontFormat = "woff2";
          if (chosenUrl.includes(".woff2")) fontFormat = "woff2";
          else if (chosenUrl.includes(".woff")) fontFormat = "woff";
          else if (chosenUrl.includes(".ttf")) fontFormat = "truetype";
          else if (chosenUrl.includes(".otf")) fontFormat = "opentype";

          let ruleCss = `@font-face {\n  font-family: '${ruleObj.family}';\n  src: url('${dataUri}') format('${fontFormat}');\n  font-display: block;\n`;
          if (ruleObj.weight) ruleCss += `  font-weight: ${ruleObj.weight};\n`;
          if (ruleObj.style) ruleCss += `  font-style: ${ruleObj.style};\n`;
          ruleCss += `}`;
          return ruleCss;
        } catch (e) {
          console.warn(`Failed to inline font for ${ruleObj.family}:`, e);
          return "";
        }
      })
    );

    return [...inlinedRules.filter(Boolean), ...paletteRules].join("\n");
  } catch (e) {
    console.warn("buildInlinedFontCss error:", e);
    return "";
  }
}

async function fetchFontAsBase64(url) {
  if (fontDataUriCache.has(url)) {
    return fontDataUriCache.get(url);
  }

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to load font from ${url}: HTTP ${response.status}`);
  }
  const blob = await response.blob();
  const dataUri = await new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });

  fontDataUriCache.set(url, dataUri);
  return dataUri;
}

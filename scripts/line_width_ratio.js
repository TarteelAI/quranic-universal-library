function calculateLineWidthRatios() {
  let pages = document.querySelectorAll(".page");
  let results = {};

  pages.forEach((page) => {
    let pageNumber = parseInt(page.id.replace("page-", ""), 10);
    let totalWidth = page.getBoundingClientRect().width;

    // Use 90% width for pages 1 and 2, otherwise 100%
    if (pageNumber === 1 || pageNumber === 2) {
      totalWidth *= 0.9;
    }

    let lines = page.querySelectorAll(".line-container");
    let lineRatios = {};

    lines.forEach((line) => {
      let lineNumber = line.dataset.line;
      let lineWidth = 0;
      let ayahs = line.querySelectorAll(".ayah-container");

      if(ayahs.length === 0)
        return; // surah name or bismillah line. No need to calculate the width ratio.

      ayahs.forEach((ayah) => {
        lineWidth += ayah.getBoundingClientRect().width;
      });

      let ratio = lineWidth / totalWidth;

      lineRatios[lineNumber] = parseFloat(ratio.toFixed(2));
    });

    if (Object.keys(lineRatios).length > 0) {
      results[pageNumber] = lineRatios;
    }
  });

  return results;
}

function detectLineWidthAnomalies(results, deviationThreshold = 0.2) {
  let anomalies = {};

  Object.entries(results).forEach(([pageNumber, lineRatios]) => {
    const ratios = Object.values(lineRatios);

    const avg =
      ratios.reduce((sum, val) => sum + val, 0) / ratios.length;

    Object.entries(lineRatios).forEach(([lineNumber, ratio]) => {
      const diff = Math.abs(ratio - avg);

      // If ratio differs more than `20%` from average → anomaly
      if (diff / avg > deviationThreshold) {
        if (!anomalies[pageNumber]) anomalies[pageNumber] = [];
        anomalies[pageNumber].push({
          line: lineNumber,
          ratio,
          average: avg.toFixed(2),
          difference: diff.toFixed(2)
        });
      }
    });
  });

  console.log("Line Width Anomalies:", anomalies);
  return anomalies;
}

function detectPagesWithCustomWidth(results) {
  let filtered = {};

  Object.entries(results).forEach(([pageNumber, lineRatios]) => {
    let reduced = {};

    Object.entries(lineRatios).forEach(([lineNumber, ratio]) => {
      if (ratio < 1) {
        reduced[lineNumber] = ratio;
      }
    });

    if (Object.keys(reduced).length > 0) {
      filtered[pageNumber] = reduced;
    }
  });

  return filtered;
}

let results = calculateLineWidthRatios();
let anomalies = detectLineWidthAnomalies(results);

console.log("================================");
console.log("Anomalies\n", JSON.stringify(anomalies, null, 2));
console.log("================================");
console.log("Pages with custom line width ratios:", JSON.stringify(detectPagesWithCustomWidth(results, 0.2), null, 2));


function detectLineAnomalies() {
  let pages = document.querySelectorAll(".page");
  let anomalies = [];

  const excludedLines = ["line--center", "line--surah-name", "line--bismillah"];

  pages.forEach((page) => {
    let pageNumber = parseInt(page.id.replace("page-", ""), 10);

    let lines = [...page.querySelectorAll(".line")].filter(
      line => !excludedLines.some(cls => line.classList.contains(cls))
    );

    let stats = lines.map((line) => {
      let rect = line.getBoundingClientRect();
      let totalLineWidth = rect.width;

      let ayahs = line.querySelectorAll(".ayah-container");
      let wordWidths = [...ayahs].map(a => a.getBoundingClientRect().width);
      let totalWordsWidth = wordWidths.reduce((a, b) => a + b, 0);

      let spacing = totalLineWidth - totalWordsWidth;
      let spacingRatio = spacing / totalLineWidth;

      return {
        line,
        lineNum: line.parentElement.dataset.line,
        wordCount: ayahs.length,
        spacingRatio
      };
    });

    if (stats.length === 0) return;

    let medianWordCount = median(stats.map(s => s.wordCount));
    let medianSpacing = median(stats.map(s => s.spacingRatio));

    // Detect anomalies
    stats.forEach((s) => {
      let wordCountOff = Math.abs(s.wordCount - medianWordCount) >= 2;
      let spacingOff = Math.abs(s.spacingRatio - medianSpacing) > 0.15;

      if (wordCountOff || spacingOff) {
        anomalies.push({
          page: pageNumber,
          line: s.lineNum,
          wordCount: s.wordCount,
          medianWordCount,
          spacingRatio: s.spacingRatio.toFixed(2),
          medianSpacing: medianSpacing.toFixed(2),
          type: [
            wordCountOff ? "Word Count" : null,
            spacingOff ? "Spacing" : null
          ].filter(Boolean).join(", ")
        });
      }
    });
  });

  console.table(anomalies);
  return anomalies;
}

function median(arr) {
  arr = [...arr].sort((a, b) => a - b);
  let mid = Math.floor(arr.length / 2);
  return arr.length % 2 === 0
    ? (arr[mid - 1] + arr[mid]) / 2
    : arr[mid];
}

// Run detection
detectLineAnomalies();

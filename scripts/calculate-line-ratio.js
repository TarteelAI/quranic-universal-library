function calculateLineWidthRatios(onlyCenterLine = true, pageWidth) {
  let pages = document.querySelectorAll(".page");
  let results = {};

  pages.forEach((page) => {
    let pageNumber = parseInt(page.id.replace("page-", ""), 10);
    let totalWidth = pageWidth || page.getBoundingClientRect().width;
    let maxWidth = 1;

    // Use 90% width for pages 1 and 2, otherwise 100%
    if (pageNumber === 1 || pageNumber === 2) {
      totalWidth *= 0.9;
      maxWidth = 0.9;
    }

    let lines;

    if(onlyCenterLine){
       lines = page.querySelectorAll(".line.line--center");
    } else{
      lines = page.querySelectorAll(".line");
    }
    let lineRatios = {};

    lines.forEach((line) => {
      let lineNumber = line.parentElement.dataset.line;
      let lineWidth = 0;
      let ayahs = line.querySelectorAll(".ayah-container");

      ayahs.forEach((ayah) => {
        lineWidth += ayah.getBoundingClientRect().width;
      });

      let ratio = lineWidth / totalWidth;

      // Ensure ratio does not exceed 1
      lineRatios[lineNumber] = Math.min(parseFloat(ratio.toFixed(2)), maxWidth);
    });

    if (Object.keys(lineRatios).length > 0) {
      results[pageNumber] = lineRatios;
    }
  });

  console.log(results);
  return results;
}

let results = calculateLineWidthRatios();
console.log(JSON.stringify(results));

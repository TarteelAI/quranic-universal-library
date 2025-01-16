function calculateLineWidthRatios() {
  let pages = document.querySelectorAll('.page');
  let results = {};

  pages.forEach(page => {
    let pageNumber = page.id.replace("page-", ""); // Extract page number
    let totalWidth = page.getBoundingClientRect().width; // 90% of total width

    let lines = page.querySelectorAll('.line.line--center');
    let pageRatios = {};

    lines.forEach(line => {
      let lineNumber = line.parentElement.dataset.line; // Get line number
      let lineWidth = 0;
      let ayahs = line.querySelectorAll('.ayah-container');

      ayahs.forEach(ayah => {
        lineWidth += ayah.getBoundingClientRect().width;
      });

      let ratio = lineWidth / totalWidth; // Use 90% of total width
      pageRatios[lineNumber] = parseFloat(ratio.toFixed(2));
    });

    if (Object.keys(pageRatios).length > 0) {
      results[pageNumber] = pageRatios;
    }
  });

  console.log(results);
  return results;
}

results = calculateLineWidthRatios();
JSON.stringify(results)

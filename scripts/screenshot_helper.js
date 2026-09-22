const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function renderImage(options) {
  const {
    url,
    html,
    htmlFile,
    outputPath,
    format = 'png',
    scale = 2,
    transparent = false
  } = options;

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({
      width: 1200,
      height: 1600,
      deviceScaleFactor: parseInt(scale, 10) || 2
    });

    if (htmlFile && fs.existsSync(htmlFile)) {
      const htmlContent = fs.readFileSync(htmlFile, 'utf-8');
      await page.setContent(htmlContent, { waitUntil: ['networkidle0', 'domcontentloaded'], timeout: 30000 });
    } else if (html) {
      await page.setContent(html, { waitUntil: ['networkidle0', 'domcontentloaded'], timeout: 30000 });
    } else if (url) {
      await page.goto(url, { waitUntil: ['networkidle0', 'domcontentloaded'], timeout: 30000 });
    }

    await page.waitForSelector('#content', { visible: true, timeout: 10000 });
    await page.evaluateHandle('document.fonts.ready');

    // Wait a brief moment to ensure all glyph layout settles
    await new Promise(r => setTimeout(r, 150));

    const element = await page.$('#content');
    if (!element) {
      throw new Error("Element #content not found on page.");
    }

    if (outputPath) {
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      await element.screenshot({
        path: outputPath,
        type: format === 'webp' ? 'webp' : 'png',
        omitBackground: transparent
      });
      console.log(JSON.stringify({ success: true, path: outputPath }));
    } else {
      const buffer = await element.screenshot({
        type: format === 'webp' ? 'webp' : 'png',
        omitBackground: transparent
      });
      process.stdout.write(buffer);
    }
  } finally {
    await browser.close();
  }
}

// CLI usage: node scripts/screenshot_helper.js <url_or_htmlFile> <outputPath> <format> <scale> <transparent>
if (require.main === module) {
  const args = process.argv.slice(2);
  const [target, outputPath, format, scale, transparent] = args;

  if (!target) {
    console.error("Usage: node scripts/screenshot_helper.js <url_or_htmlFile> [outputPath] [format] [scale] [transparent]");
    process.exit(1);
  }

  const isFile = fs.existsSync(target);

  renderImage({
    url: isFile ? null : target,
    htmlFile: isFile ? target : null,
    outputPath,
    format: format || 'png',
    scale: scale || 2,
    transparent: transparent === 'true'
  }).catch(err => {
    console.error(err);
    process.exit(1);
  });
}

module.exports = { renderImage };

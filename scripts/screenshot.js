const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Script and export settings
// possible values: code_v1, code_v2, code_v4, text_qpc_hafs
// text_uthmani_tajweed, text_qpc_nastaleeq, text_indopak_nastaleeq,
// text_digital_khatt, text_uthmani
const scriptType = 'code_v4';
const exportType = 'mushaf_page'; // Possible values: word, mushaf_page, ayah
const mushafId= 19;
const exportQuality = 100;
const exportFormat = "png";
const host = "http://localhost:3000/exports";

// Load data for ayahs and words
const ayahData = JSON.parse(fs.readFileSync("ayah_words.json", 'utf-8'));

// Main export functions
const exportWords = async (browser) => {
  for (let ayah = 1; ayah <= 6236; ayah++) {
    const { key, words } = ayahData[ayah] || {};
    for (let word = 1; word <= words; word++) {
      const url = `${host}/word?word=${key}:${word}&script=${scriptType}`;
      await captureScreenshot(browser, url, 'word');
    }
  }
};

const exportAyahs = async (browser) => {
  for (let ayah = 1; ayah <= 6236; ayah++) {
    const url = `${host}/ayah?ayah=${ayah}&script=${scriptType}`;
    await captureScreenshot(browser, url, 'ayah');
  }
};

const exportMushafPage = async (browser) => {
  for (let page = 1; page <= 604; page++) {
    const url = `${host}/mushaf_page?page_number=${page}&mushaf_id=${mushafId}}`;
    await captureScreenshot(browser, url, 'mushaf_page');
  }
};

// Screenshot helper
const captureScreenshot = async (browser, url, type) => {
  const page = await browser.newPage();
  await page.setViewport({
    width: 1920,
    height: 1080,
    deviceScaleFactor: 2, // Increase scale factor for higher resolution
  });

  try {
    await page.goto(url, { waitUntil: ['networkidle0', 'domcontentloaded'] });
    await page.waitForSelector('#content', { visible: true });
    await page.evaluateHandle('document.fonts.ready');

    const filename = await page.evaluate(() => {
      const content = document.querySelector('#content');
      return content ? content.getAttribute('data-file-name') : `screenshot_${type}_${Date.now()}`;
    });

    const elementHandle = await page.$('#content');
    if (elementHandle) {
      const boundingBox = await elementHandle.boundingBox();
      const options = {
        clip: {
          x: boundingBox.x,
          y: boundingBox.y,
          width: Math.ceil(boundingBox.width),
          height: Math.ceil(boundingBox.height),
        },
        omitBackground: true,
        type: exportFormat
      };

      const buffer = await page.screenshot(options);
      const exportPath = path.join(__dirname, `exported_data/`, `${filename}.${exportFormat}`);
      fs.mkdirSync(path.dirname(exportPath), { recursive: true });
      fs.writeFileSync(exportPath, buffer);

      console.log(`Exported: ${exportPath}`);
    } else {
      console.error("Content element not found, skipping screenshot.");
    }
  } catch (error) {
    console.error(`Failed to capture screenshot for ${url}:`, error);
  } finally {
    await page.close();
  }
};

// Main function
(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });

  try {
    switch (exportType) {
      case 'word':
        await exportWords(browser);
        break;
      case 'ayah':
        await exportAyahs(browser);
        break;
      case 'mushaf_page':
        await exportMushafPage(browser);
        break;
      default:
        console.error(`Invalid export type: ${exportType}`);
    }
  } catch (error) {
    console.error("Error during export:", error);
  } finally {
    await browser.close();
  }
})();

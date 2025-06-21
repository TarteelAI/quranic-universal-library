const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Script and export settings
// possible values: code_v1, code_v2, code_v4, text_qpc_hafs
// text_uthmani_tajweed, text_qpc_nastaleeq, text_indopak_nastaleeq,
// text_digital_khatt, text_uthmani
const scriptType = 'code_v1';
const exportType = 'mushaf_page'; // Possible values: word, mushaf_page, ayah
const mushafId= 2;
const totalPages= 604;
const exportQuality = 100;
const exportFormat = "png";
const exportWordPositions = false; //exportType === 'mushaf_page';
const host = "http://localhost:3000/exports";

const exportWords = async (browser) => {
  const ayahData = JSON.parse(fs.readFileSync("ayah_words.json", 'utf-8'));

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
  for (let page = 1; page <= totalPages; page++) {
    const url = `${host}/mushaf_page?page_number=${page}&mushaf_id=${mushafId}}`;
    await captureScreenshot(browser, url, 'mushaf_page');
  }
};

const captureScreenshot = async (browser, url, type) => {
  const page = await browser.newPage();
  await page.setViewport({
    width: 1000,
    height: 1437,
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

    if(exportWordPositions){
      const postionsData = await extractWordPositions(page, false);
      const postionExportPath = path.join(__dirname, `exported_data/`, `${filename}.json`);
      fs.mkdirSync(path.dirname(postionExportPath), { recursive: true });
      fs.writeFileSync(postionExportPath, JSON.stringify(postionsData));
    }

    const elementHandle = await page.$('#content');
    if (elementHandle) {
      const boundingBox = await elementHandle.boundingBox();
      const options = {
        clip: {
          x: boundingBox.x - 5,
          y: boundingBox.y - 5,
          width: Math.ceil(boundingBox.width) + 5,
          height: Math.ceil(boundingBox.height) + 5,
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

const extractWordPositions = async (page, highlight) => {
  const positionsData = await page.evaluate((highlight) => {
    const positions = {};

    const elements = document.querySelectorAll('[data-position]');

    elements.forEach((element) => {
      const rect = element.getBoundingClientRect();
      const x = Math.round(rect.left + window.pageXOffset);
      const y = Math.round(rect.top + window.pageYOffset);
      const w = Math.round(rect.width);
      const h = Math.round(rect.height);
      positions[element.dataset.location] = { x, y, w, h };

      if(highlight){
      element.style.border = "1px solid red";
      element.style.position = "relative";

      const text = document.createElement("span");
      text.textContent = `${x},${y}-${w}x${h}`;
      text.style.position = "absolute";
      text.style.left = "0";
      text.style.top = "0";
      text.style.color = "black";
      text.style.fontSize = "10px";
      text.style.padding = "2px";
      text.style.zIndex = "1000";
      element.appendChild(text);
      }
    });

    return positions;
  }, highlight);

  return positionsData;
};

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

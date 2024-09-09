const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Path to the words.json file
const wordsFilePath = path.resolve('scripts/v4_words.json');

// Function to convert font file to Base64
function fontToBase64(fontFilePath) {
  try {
    const fontData = fs.readFileSync(fontFilePath);
    return fontData.toString('base64');
  } catch (error) {
    console.error('Error reading font file:', error);
    return '';
  }
}

(async () => {
  // Read and parse words.json
  let words;
  try {
    const wordsData = fs.readFileSync(wordsFilePath, 'utf-8');
    words = JSON.parse(wordsData);
  } catch (error) {
    console.error('Error reading or parsing v4_words.json:', error);
    return;
  }

  // Launch the browser in non-headless mode to show the window
  const browser = await puppeteer.launch({ headless: false, defaultViewport: null });
  const page = await browser.newPage();

  const generatePage = () => {

  }

  for (const item of words) {
    const { text, filename, font, filepath } = item;
    const parts = filename.split(".")[0].split("-")


    // Path to the font file
    const fontFilePath = path.resolve(`scripts/ttf/${font}`);
    const fontBase64 = fontToBase64(fontFilePath);

    if (!fontBase64) {
      console.error(`Failed to encode font: ${font}`);
      continue;
    }

    // HTML content with @font-face rule and embedded Base64 font
    const content = `
      <html>
        <head>
          <style>
            @font-face {
              font-family: 'CustomFont';
              src: url(data:font/ttf;base64,${fontBase64}) format('truetype');
            }
            body {
              margin: 0;
              display: flex;
              align-items: center;
              justify-content: center;
              height: 100vh;
              background-color: transparent;
            }
            div.word {
              background-color: transparent;
              font-family: 'CustomFont';
              font-size: 36px;
              color: black; 
              padding-right: 3px;
            }
          </style>
        </head>
        <body>
          <div><div class="word">${text}</div></div>
        </body>
      </html>`;

    await page.setContent(content);

    // Measure the element's size to adjust the screenshot dimensions
    const elementHandle = await page.$('div');
    if (elementHandle) {
      const boundingBox = await elementHandle.boundingBox();

      // Create a filename based on the entry's filename field
      const outputFilename = `${filepath}${filename}`;

      // Screenshot only the text element
      const buffer = await page.screenshot({
        clip: {
          x: boundingBox.x,
          y: boundingBox.y,
          width: Math.ceil(boundingBox.width),
          height: Math.ceil(boundingBox.height),
        }
      });

      // Save the screenshot with the custom filename
      fs.writeFileSync(`${outputFilename}`, buffer);
      console.log(`Saved screenshot: ${outputFilename}`);
    } else {
      console.error(`Failed to find element for text: ${text}`);
    }
  }

  await browser.close();
})();

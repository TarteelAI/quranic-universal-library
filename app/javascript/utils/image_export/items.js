// Pure helpers that turn the export form state into export-page URLs.
//
// `state` shape (all values read from the controller's form targets):
//   type: "mushaf_page" | "ayah" | "word"
//   urls: { page, ayah, word }                    base export URLs
//   mushafId, page, fromPage, toPage
//   ayahSurah, ayah, fromAyah, toAyah
//   wordSurah, wordAyah, word, fromWord, toWord
//   script, fontSize, transparent

const pad3 = (value) => value.toString().padStart(3, "0");

const transparentParam = (state) => (state.transparent ? "&transparent=true" : "");

function pageUrl(state, page) {
  return `${state.urls.page}?page_number=${page}&mushaf_id=${state.mushafId}${transparentParam(state)}`;
}

function ayahUrl(state, ayah) {
  return `${state.urls.ayah}?ayah=${state.ayahSurah}:${ayah}&script=${state.script}&font_size=${state.fontSize}${transparentParam(state)}`;
}

function wordUrl(state, word) {
  return `${state.urls.word}?word=${state.wordSurah}:${state.wordAyah}:${word}&script=${state.script}&font_size=${state.fontSize}${transparentParam(state)}`;
}

function range(from, to) {
  const start = Math.min(from, to);
  const end = Math.max(from, to);
  const values = [];
  for (let i = start; i <= end; i++) values.push(i);
  return values;
}

export function buildExportUrl(state) {
  switch (state.type) {
    case "mushaf_page": return pageUrl(state, state.page);
    case "ayah": return ayahUrl(state, state.ayah);
    case "word": return wordUrl(state, state.word);
    default: return "";
  }
}

export function generateFilename(state) {
  switch (state.type) {
    case "mushaf_page":
      return `mushaf_${state.mushafId}_page_${pad3(state.page)}`;
    case "ayah":
      return `ayah_${pad3(state.ayahSurah)}_${pad3(state.ayah)}_${state.script}`;
    case "word":
      return `word_${pad3(state.wordSurah)}_${pad3(state.wordAyah)}_${pad3(state.word)}_${state.script}`;
  }
}

// Returns [{ label, shortLabel, filename, url }] for the selected batch range.
export function buildBatchItems(state) {
  switch (state.type) {
    case "mushaf_page":
      return range(state.fromPage, state.toPage).map((p) => ({
        label: `Mushaf ${state.mushafId} Page ${p}`,
        shortLabel: `Page ${p}`,
        filename: `mushaf_${state.mushafId}_page_${pad3(p)}`,
        url: pageUrl(state, p)
      }));
    case "ayah":
      return range(state.fromAyah, state.toAyah).map((a) => ({
        label: `Ayah ${state.ayahSurah}:${a}`,
        shortLabel: `Ayah ${state.ayahSurah}:${a}`,
        filename: `ayah_${pad3(state.ayahSurah)}_${pad3(a)}_${state.script}`,
        url: ayahUrl(state, a)
      }));
    case "word":
      return range(state.fromWord, state.toWord).map((w) => ({
        label: `Word ${state.wordSurah}:${state.wordAyah}:${w}`,
        shortLabel: `Word ${state.wordSurah}:${state.wordAyah}:${w}`,
        filename: `word_${pad3(state.wordSurah)}_${pad3(state.wordAyah)}_${pad3(w)}_${state.script}`,
        url: wordUrl(state, w)
      }));
    default:
      return [];
  }
}


import { createApp } from "vue";
import App from "./App.vue";
import PolarityCheck from "./PolarityCheck.vue";
import IngestNew from "./IngestNew.vue";
import IngestProgress from "./IngestProgress.vue";
import IngestSurah from "./IngestSurah.vue";

const el = document.getElementById("audio-repair-app");

if (el) {
  const app = createApp(App, {
    sessionId: el.dataset.sessionId,
    verseKey: el.dataset.verseKey
  });
  app.mount("#audio-repair-app");
}

const polarity = document.getElementById("audio-repair-polarity");

if (polarity) {
  const parse = (value) => {
    try {
      return JSON.parse(value || "[]");
    } catch {
      return [];
    }
  };
  createApp(PolarityCheck, {
    recitations: parse(polarity.dataset.recitations),
    recent: parse(polarity.dataset.recent),
    initialId: polarity.dataset.checkId || null
  }).mount("#audio-repair-polarity");
}

const ingestNew = document.getElementById("audio-repair-ingest-new");

if (ingestNew) {
  const parse = (value) => {
    try {
      return JSON.parse(value || "[]");
    } catch {
      return [];
    }
  };
  createApp(IngestNew, {
    reciters: parse(ingestNew.dataset.reciters),
    styles: parse(ingestNew.dataset.styles),
    qiratTypes: parse(ingestNew.dataset.qiratTypes),
    previewUrl: ingestNew.dataset.previewUrl,
    createUrl: ingestNew.dataset.createUrl,
    csrf: ingestNew.dataset.csrf || ""
  }).mount("#audio-repair-ingest-new");
}

const ingest = document.getElementById("audio-repair-ingest");

if (ingest) {
  createApp(IngestProgress, {
    dataUrl: ingest.dataset.dataUrl,
    downloadUrl: ingest.dataset.downloadUrl,
    retryUrl: ingest.dataset.retryUrl,
    itemUrl: ingest.dataset.itemUrl,
    detectUrl: ingest.dataset.detectUrl,
    approveUrl: ingest.dataset.approveUrl,
    encodeUrl: ingest.dataset.encodeUrl,
    cleanupUrl: ingest.dataset.cleanupUrl,
    settingsUrl: ingest.dataset.settingsUrl,
    surahUrl: ingest.dataset.surahUrl,
    updateSourceUrl: ingest.dataset.updateSourceUrl,
    uploadUrl: ingest.dataset.uploadUrl,
    encodeSelectedUrl: ingest.dataset.encodeSelectedUrl,
    previewUrl: ingest.dataset.previewUrl
  }).mount("#audio-repair-ingest");
}

const surah = document.getElementById("audio-repair-surah");

if (surah) {
  createApp(IngestSurah, {
    dataUrl: surah.dataset.dataUrl,
    reencodeUrl: surah.dataset.reencodeUrl,
    polarityUrlEndpoint: surah.dataset.polarityUrl,
    backUrl: surah.dataset.backUrl
  }).mount("#audio-repair-surah");
}

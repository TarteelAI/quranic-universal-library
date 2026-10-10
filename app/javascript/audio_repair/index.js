import { createApp } from "vue";
import App from "./App.vue";
import PolarityCheck from "./PolarityCheck.vue";

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

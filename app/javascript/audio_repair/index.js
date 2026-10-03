import { createApp } from "vue";
import App from "./App.vue";

const el = document.getElementById("audio-repair-app");

if (el) {
  const app = createApp(App, {
    sessionId: el.dataset.sessionId,
    verseKey: el.dataset.verseKey
  });
  app.mount("#audio-repair-app");
}

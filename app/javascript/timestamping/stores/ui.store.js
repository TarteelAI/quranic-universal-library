// stores/ui.store.js
import { defineStore } from 'pinia';

export const useUiStore = defineStore('ui', {
  state: () => ({
    showSegments: true,
    showWaveform: false,
    autoScroll: true,
    alert: null,
    editMode: false,
    autoSave: false,
    disableHotkeys: true
  }),
  actions: {
    showAlert(message) {
      this.alert = message;
      setTimeout(() => this.alert = null, 3000);
    },
    toggleSetting(setting) {
      this[setting] = !this[setting];
    }
  }
});
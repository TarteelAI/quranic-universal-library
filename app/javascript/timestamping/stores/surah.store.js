// stores/surah.store.js
import { defineStore } from 'pinia';
import { useAudioStore } from './audio.store';
import { useSegmentsStore } from './segments.store';

export const useSurahStore = defineStore('surah', {
  state: () => ({
    chapter: 0,
    versesCount: 0,
    currentVerseNumber: 1,
    currentVerseKey: null,
  }),
  actions: {
    initialize(payload) {
      this.chapter = payload.chapter;
      this.versesCount = payload.versesCount;
      this.currentVerseNumber = Number(payload.verse || 1);
      this.currentVerseKey = `${this.chapter}:${this.currentVerseNumber}`;
      this.audioType = payload.audioType || 'chapter';
    },
    async loadAyah(verse) {
      const segmentsStore = useSegmentsStore();
      const audioStore = useAudioStore();

      this.currentVerseNumber = verse;
      this.currentVerseKey = `${this.chapter}:${verse}`;

      segmentsStore.current = this.original[this.currentVerseKey] || { segments: [] };
      segmentsStore.wordsText = this.original[this.currentVerseKey]?.words || [];

      if (this.audioType === 'ayah') {
        audioStore.quranicAudioUrl = segmentsStore.current.audioUrl;
        audioStore.src = audioStore.quranicAudioUrl;
      }

      segmentsStore.loadLocalSegments(this.currentVerseKey);
      this.initializeMissingSegments();
    },
    initializeMissingSegments() {
      const segmentsStore = useSegmentsStore();
      if (segmentsStore.current.segments.length < segmentsStore.wordsText.length - 1) {
        for (let index = 1; index < segmentsStore.wordsText.length; index++) {
          if (!segmentsStore.current.segments[index]) {
            segmentsStore.current.segments.push([index]);
          }
        }
      }
    }
  }
});
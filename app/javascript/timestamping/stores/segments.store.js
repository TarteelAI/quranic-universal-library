import { defineStore } from 'pinia';
import LocalStore from '../../utils/LocalStore';
import { findSegment, findVerseSegment } from '../helper/findSegment';

const localStore = new LocalStore();

export const useSegmentsStore = defineStore('segments', {
  state: () => ({
    current: null,
    raw: {},
    original: {},
    verseOriginal: null,
    wordsText: [],
    currentWord: 1,
    currentRawWord: null,
    repeatGroups: [],
    changed: false,
    locked: false,
    rawVisible: true
  }),
  actions: {
    loadLocalSegments(verseKey) {
      const surahStore = useSurahStore();
      const stored = localStore.get(
        `${surahStore.audioType}-${surahStore.recitation}-${verseKey}`
      );
      if (stored) {
        this.current.segments = JSON.parse(stored).segments;
      }
    },
    updateSegment(payload) {
      if (payload.type === 'start') {
        this.current.segments[payload.index][1] = payload.time;
      } else {
        this.current.segments[payload.index][2] = payload.time;
      }
      this.changed = true;
    },
    async saveSegments() {
      const surahStore = useSurahStore();

      const params = {
        chapter_id: surahStore.chapter,
        verse_key: surahStore.currentVerseKey,
        segments: this.current.segments
      };

      try {
        const response = await fetch(`/${surahStore.segmentsUrl}/${surahStore.recitation}/save_segments.json`, {
          method: 'POST',
          headers: this.getHeaders(),
          body: JSON.stringify(params)
        });

        localStore.remove(`${surahStore.audioType}-${surahStore.recitation}-${surahStore.currentVerseKey}`);
        this.original[surahStore.currentVerseKey] = { ...response.segments };
      } catch (error) {
        localStore.set(
          `${surahStore.audioType}-${surahStore.recitation}-${surahStore.currentVerseKey}`,
          JSON.stringify(params)
        );
      }
    },
    getHeaders() {
      const headers = { 'Content-Type': 'application/json' };
      const csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (csrfToken) headers['X-CSRF-Token'] = csrfToken.content;
      return headers;
    }
  }
});
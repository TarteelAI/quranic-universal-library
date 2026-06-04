import {
  createStore,
  createLogger
} from "vuex";

import {findSegment, findVerseSegment} from "../helper/findSegment";
import LocalStore from "../../utils/LocalStore";
import {playAyah} from "../helper/audio";
import {divideSegmentTime, hasTiming} from "../helper/segmentTime";

const debug = process.env.NODE_ENV !== "production";

// Distinct colors for compare sources. The default (api/current) segments keep
// their own green highlight, so green is intentionally not in this palette.
const COMPARE_COLORS = ["#2563eb", "#dc2626", "#9333ea", "#ea580c", "#0d9488", "#db2777", "#ca8a04", "#4f46e5"];

const localStore = new LocalStore();

// Insert placeholders for missing words in sequence, keeping repeated runs intact.
function fillMissingWords(rawSegments, lastWord) {
  const filled = [];
  let previousWord = 0;

  (rawSegments || []).forEach((segment) => {
    const wordPosition = segment[0];

    for (var missing = previousWord + 1; missing < wordPosition; missing++) {
      filled.push([missing]);
    }

    filled.push(segment);
    previousWord = wordPosition;
  });

  for (var trailing = previousWord + 1; trailing <= lastWord; trailing++) {
    filled.push([trailing]);
  }

  return filled;
}

// Stable, type-tolerant projection of segments for comparing two versions
// (edited values arrive as strings, saved values as numbers).
function normalizeForCompare(segments) {
  return JSON.stringify((segments || []).map((segment) => {
    const num = (value) => (value === undefined || value === null || value === '') ? null : Number(value);
    return [num(segment[0]), num(segment[1]), num(segment[2]), !!(segment[3] && segment[3].waqaf)];
  }));
}

// Mark segments as unsaved whenever a user driven mutation edits them. LOAD_AYAH
// rebuilds the segments directly (not through these mutations) so navigation
// does not falsely flag the freshly loaded ayah as dirty.
const SEGMENT_EDIT_MUTATIONS = [
  "TRACK_SEG_START",
  "TRACK_SEG_END",
  "TRACK_SEG_WAQAF",
  "SET_SEG_WORD_NUMBER",
  "INSERT_REPEAT_SEG_AFTER",
  "REMOVE_SEGMENT",
  "INSERT_SEG_AFTER",
  "SPLIT_SEGMENT_TIME",
  "FILL_SEGMENT_TIME",
  "ADJUST_SEG_TIME",
  "CLEAR_SEGMENTS",
  "RELOAD_SEGMENTS",
];

const trackUnsavedSegments = (store) => {
  store.subscribe((mutation, state) => {
    if (!SEGMENT_EDIT_MUTATIONS.includes(mutation.type)) return;

    state.segmentsUnsaved = true;

    if (state.verseSegment) {
      state.undoStack.push(JSON.parse(JSON.stringify(state.verseSegment.segments)));
      if (state.undoStack.length > 100) state.undoStack.splice(1, 1);
      state.redoStack = [];
    }
  });
};

const store = createStore({
  state() {
    return {
      chapter: 0,
      versesCount: 0,
      currentVerseNumber: 1,
      currentVerseKey: null,
      currentWord: 1,
      wordsText: [],
      verseSegment: null,
      compareSources: [],
      compareActiveWords: {},
      compareSourceSeq: 0,
      verseOriginalSegment: null,
      recitation: null,
      segments: {},
      originalSegments: {},
      audioSrc: null,
      fromFile: false,
      quranicAudioUrl: null,
      alert: null,
      currentTimestamp: 0,
      currentAyahTimeFrom: 0,
      currentAyahTimeTo: 0,
      stepDuration: 2,
      segmentChanged: false,
      isLooingAyah: false,
      isLooingWord: false,
      wordLoopTime: -1,
      loopingWord: null,
      playingWord: null,
      playingWordEnd: null,

      // Options
      showSegments: true,
      showTimeline: false,
      showWaveform: false,
      autoScroll: true,
      playing: false,
      playbackSpeed: 1,
      autoSave: false,
      autoSaveSegments: false,
      segmentsUnsaved: false,
      segmentsSaved: false,
      saving: false,
      loadedSegments: [],
      undoStack: [],
      redoStack: [],
      editMode: false,
      lockAyah: false, // stop playing next ayah
      segmentLocked: false,
      audioType: 'chapter', //or ayah
      compareSegment: false,
      segmentsUrl: 'surah_audio_files',
      autoPlay: false,
      disableHotkeys: false,

      repeatGroups: [], // only need for recitation 168
      isManualAyahChange: false
    };
  },
  getters: {},
  mutations: {
    SETUP(state, payload) {
      state.chapter = payload.chapter;
      state.versesCount = payload.versesCount;
      state.currentVerseNumber = Number(payload.verse || 1);
      state.currentVerseKey = `${state.chapter}:${state.currentVerseNumber}`;
      state.recitation = payload.recitation;
      state.compareSegment = !!payload.compareSegment
      state.audioType = payload.audioType || 'chapter';
      state.segmentLocked = payload.segmentLocked == 'true';
      state.segmentsUrl = payload.segmentsUrl || "surah_audio_files";
      state.autoPlay = payload.autoPlay === 'true';
    },
    SET_PLAYBACK_SPEED(state, payload) {
      state.playbackSpeed = payload.value;
    },
    SET_STEP_DURATION(state, payload) {
      state.stepDuration = Number(payload.value);
    },
    SET_ALERT(state, payload) {
      state.alert = payload.text;
    },
    SET_SEGMENTS(state, payload) {
      state.segments = payload.segments;
      state.originalSegments = JSON.parse(JSON.stringify(state.segments));
    },
    UPDATE_SEGMENTS(state, payload) {
      state.segments = {
        ...state.segments,
        ...payload.segments
      };
      state.originalSegments = JSON.parse(JSON.stringify(state.segments));
    },
    CLEAR_SEGMENTS(state) {
      state.verseSegment.segments = state.verseSegment.segments.map(segment => [segment[0]]);
    },
    RELOAD_SEGMENTS(state) {
      state.verseSegment.segments = state.originalSegments[state.currentVerseKey].segments;
    },
    ADD_COMPARE_SOURCE(state) {
      const color = COMPARE_COLORS[state.compareSources.length % COMPARE_COLORS.length];
      state.compareSourceSeq += 1;

      state.compareSources.push({
        id: state.compareSourceSeq,
        name: `Source ${state.compareSources.length + 1}`,
        color,
        text: '',
        error: false,
        segments: {},
      });
    },
    REMOVE_COMPARE_SOURCE(state, payload) {
      state.compareSources = state.compareSources.filter((source) => source.id !== payload.id);

      const active = { ...state.compareActiveWords };
      delete active[payload.id];
      state.compareActiveWords = active;
    },
    UPDATE_COMPARE_SOURCE(state, payload) {
      const source = state.compareSources.find((item) => item.id === payload.id);
      if (!source) return;

      source.text = payload.text;

      try {
        const data = payload.text.replace(/(\d+):/g, '"$1":').replace(/\s+/g, '');
        source.segments = data ? JSON.parse(data) : {};
        source.error = false;
      } catch (error) {
        source.error = true;
      }
    },
    SET_WORD(state, payload) {
      state.currentWord = Number(payload.word);
    },
    CHANGE_AYAH(state, payload) {
      let verse;

      if (payload.step) verse = state.currentVerseNumber + Number(payload.step);
      else verse = Number(payload.to);

      if (verse >= 1 || verse <= state.versesCount) {
        state.isManualAyahChange = true;
        
        state.currentVerseNumber = verse;
        state.currentTimestamp = 0;
        state.currentWord = 1;

        this.dispatch("LOAD_AYAH", {
          verse,
          autoPlay: state.autoPlay
        });
      }
    },
    TOGGLE_SEGMENTS(state) {
      state.showSegments = !state.showSegments;
    },
    TOGGLE_TIMELINE(state) {
      state.showTimeline = !state.showTimeline;
    },
    TOGGLE_AUTOSCROLL(state) {
      state.autoScroll = !state.autoScroll;
    },
    TOGGLE_WAVEFORM(state) {
      state.showWaveform = !state.showWaveform;
    },
    TOGGLE_HOTKEYS(state) {
      state.disableHotkeys = !state.disableHotkeys;
    },
    SET_AUDIO_SOURCE(state, payload) {
      state.audioSrc = payload.url;
      state.fromFile = payload.fromFile;
    },
    SET_PLAYING(state, payload) {
      state.playing = payload.value;
    },
    SET_SURAH_ENDED(state) {
      state.playing = false;
    },
    SET_AYAH_ENDED(state) {
      if (state.isLooingAyah) {
        state.currentTimestamp = 0;
        state.currentWord = 1;
        playAyah();
        return
      }

      if (state.lockAyah) {
        if (!player?.paused) player?.pause()
      } else {
        this.dispatch("LOAD_AYAH", {
          verse: state.currentVerseNumber + 1,
          autoPlay: true
        });
      }
    },
    SEGMENT_START_CHANGED(state, payload) {
      if (!payload.value) return

      const val = Number(payload.value.toFixed());
      state.verseSegment.timestamp_from = val;
      state.currentAyahTimeFrom = val;
      state.segmentChanged = true;
    },
    SEGMENT_END_CHANGED(state, payload) {
      if (!payload.value) return
      const val = Number(payload.value.toFixed());

      state.verseSegment.timestamp_to = val;
      state.currentAyahTimeTo = val;
      state.segmentChanged = true;
    },
    TOGGLE_LOOP_WORD(state, payload) {
      state.isLooingWord = !state.isLooingWord;

      if (state.isLooingWord) {
        state.currentWord = Number(payload.word) + 1;
        state.loopingWord = Number(payload.word) + 1;

        player &&
        (player.currentTime =
          state.verseSegment.segments[Number(payload.word)][1] / 1000);
      } else {
        state.loopingWord = null;
      }
    },
    PLAY_WORD(state, payload) {
      const { index } = payload;
      const segment = state.verseSegment.segments[index];
      if (!segment) return;

      const start = Number(segment[1]);
      const end = Number(segment[2]);
      if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
        state.alert = "This word has no timing to play yet.";
        return;
      }

      state.isLooingWord = false;
      state.loopingWord = null;
      state.playingWord = Number(index) + 1;
      state.playingWordEnd = end;
      state.currentWord = Number(index) + 1;

      if (player) {
        player.currentTime = start / 1000;
        playAyah();
      }
    },
    TOGGLE_LOOP_AYAH(state, payload) {
      state.isLooingAyah = !state.isLooingAyah;

      if (state.isLooingAyah) {
        state.alert = `Loop is enabled`;
      } else state.alert = `Loop is disabled`;

    },
    MARK_AYAH_START(state, payload) {
      const {
        verseSegment
      } = state;

      const val = Number(payload.value.toFixed())
      verseSegment.timestamp_from = val;
      state.currentAyahTimeFrom = val;
    },
    MARK_AYAH_END(state, payload) {
      const {
        verseSegment,
        segments,
        chapter,
        currentVerseNumber,
        autoSave,
        versesCount
      } = state;

      const val = Number(payload.value.toFixed())
      verseSegment.timestamp_to = val;
      state.currentAyahTimeTo = val;

      if (currentVerseNumber < versesCount) {
        // set start time of next segment
        segments[`${chapter}:${currentVerseNumber + 1}`].timestamp_from = val + 1;
      }

      if (autoSave) {
        this.dispatch("SAVE_AYAH_TIMESTAMP", {
          ayah: currentVerseNumber
        })
      }

      if (state.lockAyah) {
        if (!player?.paused) player?.pause()
      } else {
        this.dispatch("LOAD_AYAH", {
          verse: state.currentVerseNumber + 1,
        });
      }
    },
    SET_AUTO_SAVE(state, payload) {
      state.autoSave = payload.value;
    },
    SET_AUTO_SAVE_SEGMENTS(state, payload) {
      state.autoSaveSegments = payload.value;
    },
    SET_EDIT_MODE(state, payload) {
      state.editMode = payload.value;
    },
    SET_AYAH_LOCK(state, payload) {
      state.lockAyah = payload.value;
    },
    TRACK_SEG_START(state, payload) {
      const {
        verseSegment
      } = state;
      const {
        time,
        index
      } = payload;

      const segment = verseSegment.segments[index] || [];
      segment[1] = time;
      verseSegment.segments[index] = segment;
    },
    TRACK_SEG_END(state, payload) {
      const {
        verseSegment
      } = state;
      const {
        time,
        index
      } = payload;

      const segment = verseSegment.segments[index] || [];
      segment[2] = time;
      verseSegment.segments[index] = segment;
    },
    TRACK_SEG_WAQAF(state, payload) {
      const {
          verseSegment
      } = state;
      const {
          waqaf,
          index
      } = payload;
      const segment = verseSegment.segments[index] || [];
      if (!segment[3]) {
          segment[3] = {};
      }
      segment[3].waqaf = waqaf;
      verseSegment.segments[index] = segment;
    },
    SET_SEG_WORD_NUMBER(state, payload) {
      const {
        verseSegment
      } = state;
      const {
        index,
        word
      } = payload;

      verseSegment.segments[index][0] = word;
    },
    INSERT_REPEAT_SEG_AFTER(state, payload) {
      const {
        verseSegment,
        repeatGroups
      } = state;
      let lastRepeatWord = repeatGroups[repeatGroups.length - 1];
      let {word} = payload;

      if (!!lastRepeatWord) {
        lastRepeatWord--;
      } else {
        lastRepeatWord = 0;
      }

      var newSegments = [];

      for (var i = lastRepeatWord + 1; i < word; i++) {
        newSegments.push([i])
      }
      var index = verseSegment.segments.findIndex(segment => segment[0] > word);
      if (index == -1) index = verseSegment.segments.length + 1;

      index = index - 1;

      verseSegment.segments = [
        // segments before index
        ...verseSegment.segments.slice(0, index),
        // add new segment
        ...newSegments,
        // segments after index
        ...verseSegment.segments.slice(index),
      ]

      repeatGroups.push(word)
    },
    REMOVE_SEGMENT(state, payload) {
      const {
        verseSegment
      } = state;

      const {
        index
      } = payload;

      var segments = verseSegment.segments;
      segments.splice(index, 1);
      verseSegment.segments = segments;
    },
    INSERT_SEG_AFTER(state, payload) {
      const {
        verseSegment
      } = state;

      const {
        index,
        word
      } = payload;

      var newSegments = [
        [word]
      ];

      verseSegment.segments = [
        // segments before index
        ...verseSegment.segments.slice(0, index),
        // add new segment
        ...newSegments,
        // segments after index
        ...verseSegment.segments.slice(index),
      ]
    },
    ADJUST_SEG_TIME(state, payload) {
      const {
        index,
        field,
        delta
      } = payload;

      const segment = state.verseSegment.segments[index];
      if (!segment) return;

      const current = Number(segment[field]);
      const base = Number.isFinite(current) ? current : 0;
      const next = Math.max(0, base + delta);

      segment[field] = next;
      state.verseSegment.segments = [...state.verseSegment.segments];
    },
    UNDO_SEGMENTS(state) {
      if (state.undoStack.length <= 1) return;

      const current = state.undoStack.pop();
      state.redoStack.push(current);

      const previous = state.undoStack[state.undoStack.length - 1];
      state.verseSegment.segments = JSON.parse(JSON.stringify(previous));
      state.segmentsUnsaved = state.undoStack.length > 1;
    },
    REDO_SEGMENTS(state) {
      if (!state.redoStack.length) return;

      const next = state.redoStack.pop();
      state.undoStack.push(next);
      state.verseSegment.segments = JSON.parse(JSON.stringify(next));
      state.segmentsUnsaved = state.undoStack.length > 1;
    },
    FILL_SEGMENT_TIME(state, payload) {
      const { index } = payload;
      const segments = state.verseSegment.segments;
      const segment = segments[index];
      if (!segment) return;

      const present = (value) => value !== undefined && value !== null && value !== '';
      if (present(segment[1]) || present(segment[2])) return;

      const prev = segments[index - 1];
      const next = segments[index + 1];

      let start = (prev && present(prev[2])) ? Number(prev[2]) + 1 : Number(state.verseSegment.timestamp_from);
      let end = (next && present(next[1])) ? Number(next[1]) - 1 : Number(state.verseSegment.timestamp_to);

      if (!Number.isFinite(start)) start = 0;
      if (!Number.isFinite(end) || end < start) end = start;

      segment[1] = start;
      segment[2] = end;
      state.verseSegment.segments = [...state.verseSegment.segments];
    },
    SPLIT_SEGMENT_TIME(state, payload) {
      const {
        verseSegment,
        wordsText
      } = state;
      const {
        index
      } = payload;

      const segments = verseSegment.segments;
      const segment = segments[index];
      if (!segment) return;

      const startTime = Number(segment[1]);
      const endTime = Number(segment[2]);
      if (!Number.isFinite(startTime) || !Number.isFinite(endTime) || endTime <= startTime) return;

      const group = [index];
      for (var i = index + 1; i < segments.length; i++) {
        if (hasTiming(segments[i])) break;
        group.push(i);
      }

      if (group.length === 1) return;

      const texts = group.map((segIndex) => wordsText[segments[segIndex][0] - 1] || '');
      const ranges = divideSegmentTime(startTime, endTime, texts);

      group.forEach((segIndex, position) => {
        segments[segIndex][1] = ranges[position][0];
        segments[segIndex][2] = ranges[position][1];
      });

      verseSegment.segments = [...segments];
    }
  },
  actions: {
    SAVE_AYAH_SEGMENTS({
                         state
                       }) {
      const isPlaying = !player?.paused
      if (isPlaying) player?.pause()
      state.saving = true;

      const {
        verseSegment,
        currentVerseKey,
        recitation,
        chapter,
        audioType,
        segmentsUrl
      } = state;


      var csrfTokenElement = document.querySelector('meta[name="csrf-token"]');
      var headers = {};
      if (csrfTokenElement) headers["X-CSRF-Token"] = csrfTokenElement.content;
      headers["Content-Type"] = "application/json"

      const params = {
        chapter_id: chapter,
        verse_key: currentVerseKey,
        segments: verseSegment.segments
      };

      const requestOptions = {
        method: 'post',
        headers: headers,
        body: JSON.stringify(params)
      };

      fetch(`/${segmentsUrl}/${recitation}/save_segments.json`, requestOptions).then(response => response.json()).then(json => {
        localStore.remove(`${audioType}-${recitation}-${currentVerseKey}`);

        this.commit("UPDATE_SEGMENTS", {
          segments: json.segments
        })
        state.segmentsUnsaved = false;
        state.segmentsSaved = true;
        state.saving = false;
        state.loadedSegments = JSON.parse(JSON.stringify(state.verseSegment.segments));
        state.undoStack = [JSON.parse(JSON.stringify(state.verseSegment.segments))];
        state.redoStack = [];
      }).catch(() => {
        // save in local store
        localStore.set(`${audioType}-${recitation}-${currentVerseKey}`, JSON.stringify(params));
        state.saving = false;
        state.alert = `Sorry, can't save segments. Please refresh the page and try again.`;
      });
    },
    SAVE_AYAH_TIMESTAMP({
                          state
                        }, payload) {
      const {
        verseSegment,
        currentVerseKey,
        recitation,
        chapter,
        segments,
        audioType
      } = state;

      if (audioType == 'ayah')
        return

      state.saving = true;

      var csrfTokenElement = document.querySelector('meta[name="csrf-token"]');
      var headers = {},
        attrs;
      if (csrfTokenElement) headers["X-CSRF-Token"] = csrfTokenElement.content;
      headers["Content-Type"] = "application/json"

      const requestOptions = {
        method: 'post',
        headers: headers
      };

      if (payload.ayah) {
        const key = `${chapter}:${payload.ayah}`;
        const segment = segments[key];

        attrs = {
          recitation_id: recitation,
          verse_key: key,
          from: segment.timestamp_from,
          to: segment.timestamp_to
        };
      } else {
        attrs = {
          recitation_id: recitation,
          verse_key: currentVerseKey,
          from: verseSegment.timestamp_from,
          to: verseSegment.timestamp_to
        };
      }

      fetch(`/surah_audio_files/${recitation}/save_segments.json?${$.param(attrs)}`, requestOptions).then(response => response.json()).then(json => {
        state.segmentChanged = false;
        this.commit("UPDATE_SEGMENTS", {
          segments: json.segments
        })
        state.saving = false;
      }).catch(() => {
        state.saving = false;
      });
    },
    LOAD_AYAH({
                state
              }, payload) {
      if (state.autoSaveSegments && state.segmentsUnsaved && state.currentVerseKey) {
        this.dispatch("SAVE_AYAH_SEGMENTS");
      }

      const {
        chapter,
        segments,
        originalSegments,
        versesCount,
        recitation,
        audioType
      } = state;

      const verse = Number(payload.verse);

      if (verse < 1 || verse > versesCount) return;

      const verseKey = `${chapter}:${verse}`;

      state.currentWord = 1;
      state.verseSegment = segments[verseKey] || {
        segments: [],
      };
      state.repeatGroups = [];
      state.wordsText = segments[verseKey].words;

      state.verseOriginalSegment = originalSegments[verseKey];
      state.currentVerseNumber = verse;
      state.currentVerseKey = verseKey;
      state.fromFile = false;

      // keep the verse query param in sync with the current ayah, adding it
      // when missing so the url can always be shared for a specific ayah
      if (typeof window !== 'undefined' && window.history && window.location.pathname.includes('segment_builder')) {
        const url = new URL(window.location.href);
        url.searchParams.set('verse', verse);
        window.history.replaceState(window.history.state, '', url);
      }

      if (audioType == 'ayah') {
        state.quranicAudioUrl = state.verseSegment.audioUrl;
        state.audioSrc = state.quranicAudioUrl;
        state.autoPlay = payload.autoPlay;
      } else {
        state.currentAyahTimeFrom = state.verseSegment.timestamp_from;
        state.currentAyahTimeTo = state.verseSegment.timestamp_to;
      }

      // load segments data from localstorage
      const storedSegment = localStore.get(`${audioType}-${recitation}-${verseKey}`);
      if (storedSegment && storedSegment.length > 0) {
        state.verseSegment.segments = JSON.parse(storedSegment).segments;
      }

      const lastWord = state.wordsText.length - 1;
      const filledSegments = fillMissingWords(state.verseSegment.segments, lastWord);

      // Baseline against the saved/original segments, not the working copy, so
      // unsaved edits made before navigating away stay flagged on revisit.
      const savedSource = (originalSegments[verseKey] && originalSegments[verseKey].segments) || [];
      const savedBaseline = fillMissingWords(savedSource, lastWord);

      state.verseSegment.segments = filledSegments;
      state.loadedSegments = JSON.parse(JSON.stringify(savedBaseline));
      state.undoStack = [JSON.parse(JSON.stringify(filledSegments))];
      state.redoStack = [];
      state.segmentsUnsaved = normalizeForCompare(filledSegments) !== normalizeForCompare(savedBaseline);
      state.segmentsSaved = false;

      setTimeout(() => {
        state.isManualAyahChange = false;
      }, 100);
    },
    LOAD_SEGMENTS({state}, payload) {
      const {
        chapter,
        recitation,
        currentVerseNumber,
        segmentsUrl,
        audioType,
        currentVerseKey
      } = state;

      this.commit("SET_ALERT", {
        text: "Loading Data...",
      });

      $.get(`/${segmentsUrl}/${recitation}/segments.json?chapter_id=${chapter}&a=${Math.random()}`).then((res) => {
        this.commit("SET_SEGMENTS", {
          segments: res.segments,
        });

        if (audioType != 'ayah') {
          state.quranicAudioUrl = res.fileUrl;
        }

        state.alert = null;

        this.commit("CHANGE_AYAH", {
          to: currentVerseNumber,
        });
      });
    },
    SET_TIMESTAMP({
                    state
                  }, payload) {
      const time = payload.timestamp;
      state.currentTimestamp = time;

      const {
        currentVerseNumber,
        currentVerseKey,
        currentWord,
        segments,
        chapter,
        isLooingAyah,
        isLooingWord,
        versesCount,
        verseSegment,
        audioType
      } = state;

      if (state.compareSources.length) {
        const compareKey = audioType == 'ayah' ? currentVerseKey : currentVerseNumber;
        const active = {};

        state.compareSources.forEach((source) => {
          const sourceSegments = source.segments && source.segments[compareKey];
          if (sourceSegments && sourceSegments.length > 0) {
            active[source.id] = findVerseSegment(time, {segments: sourceSegments}).word;
          }
        });

        state.compareActiveWords = active;
      }

      if (state.playingWord) {
        if (time >= state.playingWordEnd) {
          player && player.pause();
          state.playingWord = null;
          state.playingWordEnd = null;
        }

        return;
      }

      if (isLooingWord) {
        const wordTiming = verseSegment.segments[currentWord];

        if (time > wordTiming[2]) {
          player && (player.currentTime = wordTiming[1] / 1000);
        }

        if (time < wordTiming[1]) {
          player && (player.currentTime = wordTiming[1] / 1000);
        }

        return;
      }

      if (audioType == 'ayah') {
        const {
          word
        } = findVerseSegment(
          time,
          segments[currentVerseKey],
          currentWord
        );
        state.currentWord = word;
        return;
      }

      if (!verseSegment || verseSegment.timestamp_from == undefined || verseSegment.timestamp_to == undefined) {
        return
      }

      const {
        word,
        verse
      } = findSegment(
        time,
        segments,
        currentVerseNumber,
        chapter,
        currentWord,
        versesCount
      );

      state.currentWord = word;

      if (isLooingAyah) {
        if (time > verseSegment.timestamp_to) {
          player && (player.currentTime = verseSegment.timestamp_from / 1000);
        }

        if (time < verseSegment.timestamp_from) {
          player && (player.currentTime = verseSegment.timestamp_from / 1000);
        }

        return;
      }

      if (verse && verse != currentVerseNumber) {
        if (state.lockAyah) {
          if (!player?.paused) player?.pause()
        } else {
          state.currentVerseNumber = verse;
          this.dispatch("LOAD_AYAH", {verse});
        }
      }
    }
  },
  plugins: debug ? [createLogger(), trackUnsavedSegments] : [trackUnsavedSegments],
});

export default store;
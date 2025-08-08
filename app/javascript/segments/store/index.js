import {
  createStore,
  createLogger
} from "vuex";

import {findSegment, findVerseSegment} from "../helper/findSegment";
import LocalStore from "../../utils/LocalStore";
import {playAyah} from "../helper/audio";

const debug = process.env.NODE_ENV !== "production";

const localStore = new LocalStore();

const store = createStore({
  state() {
    return {
      chapter: 0,
      versesCount: 0,
      currentVerseNumber: 1,
      currentVerseKey: null,
      currentWord: 1,
      currentRawSegmentWord: null,
      wordsText: [],
      verseSegment: null,
      rawSegments: {},
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

      // Options
      showSegments: true,
      showWaveform: false,
      autoScroll: true,
      playing: false,
      playbackSpeed: 1,
      autoSave: false,
      editMode: false,
      lockAyah: false, // stop playing next ayah
      segmentLocked: false,
      rawSegmentVisible: true, // show raw segments
      audioType: 'chapter', //or ayah
      compareSegment: false,
      segmentsUrl: 'surah_audio_files',
      autoPlay: false,
      disableHotkeys: true,

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
    SHOW_RAW_SEGMENT(state) {
      state.rawSegmentVisible = !state.rawSegmentVisible;
    },
    UPDATE_RAW_SEGMENTS(state, payload) {
      if (state.audioType == 'ayah') {
        state.rawSegments[state.currentVerseKey] = payload.segments;
      } else {
        state.rawSegments = payload.segments;
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
    }
  },
  actions: {
    SAVE_AYAH_SEGMENTS({
                         state
                       }) {
      const isPlaying = !player?.paused
      if (isPlaying) player?.pause()
      state.alert = "Saving segments";

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
        state.alert = `Saved`;
      }).catch(() => {
        // save in local store
        localStore.set(`${audioType}-${recitation}-${currentVerseKey}`, JSON.stringify(params));
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

      state.alert = `Saving ayah`;

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
        state.alert = `Saved`;
      });
    },
    LOAD_AYAH({
                state
              }, payload) {
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

      if (audioType == 'ayah') {
        state.quranicAudioUrl = state.verseSegment.audioUrl;
        state.audioSrc = state.quranicAudioUrl;
        state.autoPlay = payload.autoPlay;
      } else {
        state.currentAyahTimeFrom = state.verseSegment.timestamp_from;
        state.currentAyahTimeTo = state.verseSegment.timestamp_to;
      }

      state.alert = `Current ayah is ${verseKey}`;

      // load segments data from localstorage
      const storedSegment = localStore.get(`${audioType}-${recitation}-${verseKey}`);
      if (storedSegment && storedSegment.length > 0) {
        state.verseSegment.segments = JSON.parse(storedSegment).segments;

        this.commit("SET_ALERT", {
          text: "segments data loaded from local storage.",
        });
      }

      if (state.verseSegment.segments.length < state.wordsText.length - 1) {
        // add missing segments
        for (var index = 1; index < state.wordsText.length; index++) {
          if (!state.verseSegment.segments[index])
            state.verseSegment.segments.push([index])
        }
      }
      
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
        rawSegments,
        chapter,
        isLooingAyah,
        isLooingWord,
        versesCount,
        verseSegment,
        audioType
      } = state;

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

      const rawSegmentKey = audioType == 'ayah' ? currentVerseKey : currentVerseNumber;
      const rawAyahSegments = rawSegments[rawSegmentKey];
      if (rawAyahSegments && rawAyahSegments.length > 0) {
        const rawSegment = findVerseSegment(
          time,
          {segments: rawAyahSegments}
        );

        state.currentRawSegmentWord = rawSegment.word;
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
  plugins: debug ? [createLogger()] : [],
});

export default store;
<template>
  <div class="flex flex-wrap my-2">
    <div class="w-full flex flex-wrap items-start gap-4">
      <div class="flex flex-col gap-2">
        <div class="flex gap-1">
          <button
              class="px-3 py-1 text-xs font-medium bg-cyan-600 text-white rounded transition-colors hover:bg-cyan-700 disabled:opacity-50"
              data-step="-1"
              @click="changeAyah"
              :disabled="currentVerseNumber <= 1"
          >
            Previous ayah
          </button>
          <button
              class="px-3 py-1 text-xs font-medium bg-cyan-600 text-white rounded transition-colors hover:bg-cyan-700 disabled:opacity-50"
              data-step="1"
              @click="changeAyah"
              :disabled="currentVerseNumber >= versesCount"
          >
            Next ayah
          </button>
        </div>

        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <span class="w-full text-[10px] font-semibold uppercase tracking-wide text-gray-400">View</span>
          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="disableHotkeys"
                @change="toggleHotkeys"
                id="toggle-hotkeys"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="toggle-hotkeys"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="Toggle hotkeys">
              Disable Hotkeys
            </label>
          </div>

          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="showSegments"
                @change="toggleSegment"
                id="toggle-segments"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="toggle-segments"
                   class="ml-2 text-sm text-gray-700"
                   title="Toggle segments table.">
              Segments
            </label>
          </div>

          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="showTimeline"
                @change="toggleTimeline"
                id="toggle-timeline"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="toggle-timeline"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="Show a visual timeline of word segments.">
              Timeline
            </label>
          </div>

          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="autoScroll"
                @change="toggleAutoscroll"
                id="toggle-scroll"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="toggle-scroll"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="Autoscroll segments table to current word">
              Autoscroll
            </label>
          </div>
        </div>
      </div>

      <div class="hidden sm:block w-px self-stretch bg-gray-200"></div>

      <div class="flex gap-1">
        <button
            class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded transition-colors hover:bg-blue-700 disabled:opacity-50"
            @click="togglePlay"
            :disabled="disablePlay"
        >
          {{ playing ? "Pause" : "Play" }}
        </button>
        <button
            class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded transition-colors hover:bg-blue-700"
            @click="loopAyah"
        >
          {{ isLooingAyah ? "Looping" : "Loop" }}
        </button>
      </div>

      <div class="hidden sm:block w-px self-stretch bg-gray-200"></div>

      <div class="flex flex-col gap-1">
        <span class="text-[10px] font-semibold uppercase tracking-wide text-gray-400">Play range (ms)</span>
        <div class="flex gap-1">
          <input
              type="number"
              placeholder="Start"
              :value="playRangeStart"
              @change="playRangeStartChanged"
              class="w-20 px-2 py-1 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
              type="number"
              placeholder="End"
              :value="playRangeEnd"
              @change="playRangeEndChanged"
              class="w-20 px-2 py-1 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="flex gap-1">
          <button
              class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded transition-colors hover:bg-blue-700 disabled:opacity-50"
              @click="playRange"
              :disabled="!audioSrc"
          >
            Play range
          </button>
          <button
              class="px-3 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded transition-colors hover:bg-gray-300"
              @click="clearPlayRange"
          >
            Clear
          </button>
        </div>
      </div>

      <div class="hidden sm:block w-px self-stretch bg-gray-200"></div>

      <div class="flex flex-col gap-1">
        <div class="flex gap-1">
          <button class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded transition-colors hover:bg-blue-700" @click="stepUp">Forward</button>
          <button class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded transition-colors hover:bg-blue-700" @click="stepBack">Backward</button>
        </div>
        <div>
          <input
              type="number"
              v-model="stepDuration"
              placeholder="step duration"
              class="w-24 px-2 py-1 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      <div class="flex flex-col gap-2 ml-auto">
        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <span class="w-full text-[10px] font-semibold uppercase tracking-wide text-gray-400">Editing</span>
          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="lockAyah"
                @change="toggleLockAyah"
                id="lock-ayah"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="lock-ayah"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="If checked, player will not play the next ayah when current ayah is finished.">
              Lock ayah
            </label>
          </div>

          <div class="flex items-center">
            <input
                type="checkbox"
                :checked="editMode"
                @change="changeEditMode"
                id="edit-mode"
                :disabled="segmentLocked"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="edit-mode"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="Check this if you need to update the ayah timing when you click ayah start or end button. Clicking ayah end will also set start time of next ayah.">
              Update Ayah timing
            </label>
          </div>

          <div class="flex items-center" v-if="editMode">
            <input
                type="checkbox"
                :checked="autoSave"
                @change="changeAutoSave"
                id="auto-save"
                :disabled="segmentLocked"
                class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="auto-save"
                   class="ml-2 text-sm text-gray-700"
                   data-controller="tooltip"
                   title="Auto save will automatically save ayah the segment timestamps.">
              Auto Save
            </label>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <div v-if="editMode && audioType == 'chapter'" class="flex gap-1">
            <button
                class="px-3 py-1 text-xs font-medium bg-indigo-600 text-white rounded transition-colors hover:bg-indigo-700 disabled:opacity-50"
                @click="markAyahStart"
                :disabled="segmentLocked">
              Start
            </button>

            <button
                class="px-3 py-1 text-xs font-medium bg-indigo-600 text-white rounded transition-colors hover:bg-indigo-700 disabled:opacity-50"
                @click="markAyahEnd"
                :disabled="segmentLocked">
              End
            </button>
          </div>

          <button
              class="px-3 py-1 text-xs font-medium bg-green-600 text-white rounded transition-colors hover:bg-green-700 disabled:opacity-50"
              @click="saveAyahSegment"
              :disabled="disableSaveAyahBtn"
          >
            Save ayah
          </button>
        </div>

        <div class="flex gap-2">
          <div class="flex flex-col">
            <input
                type="number"
                placeholder="From"
                ref="ayahTimeFromInput"
                :value="currentAyahTimeFrom"
                class="w-24 px-2 py-1 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                :disabled="segmentLocked"
                @change="currentAyahTimeFromChanged"
            />
            <small class="text-xs text-gray-500" v-if="!!verseOriginalSegment">{{
                verseOriginalSegment.timestamp_from
              }}</small>
          </div>

          <div class="flex flex-col">
            <input
                type="number"
                placeholder="to"
                ref="ayahTimeToInput"
                :disabled="segmentLocked"
                :value="currentAyahTimeTo"
                class="w-24 px-2 py-1 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                @change="currentAyahTimeToChanged"
            />
            <small class="text-xs text-gray-500" v-if="!!verseOriginalSegment">{{
                verseOriginalSegment.timestamp_to
              }}</small>
          </div>
        </div>
      </div>
    </div>

    <div class="w-full mt-4">
      <Timeline />
    </div>

    <div class="w-full flex flex-wrap items-center gap-6 mt-4 p-4 bg-gray-50 rounded-lg">
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium text-gray-700">Jump to ayah:</span>
        <select
            ref="ayahSelect"
            @change="selectAyah"
            class="text-sm border border-gray-300 rounded px-2 py-0.5 bg-white focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option v-for="num in Number(versesCount)" :key="num" :value="num">{{ num }}</option>
        </select>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-sm font-medium text-gray-700">Speed:</span>
        <select @change="updatePlaybackSpeed" class="text-sm border border-gray-300 rounded px-2 py-0.5 bg-white focus:outline-none focus:ring-1 focus:ring-blue-500">
          <option value="0.3">Slowest</option>
          <option value="0.5">Slower</option>
          <option value="0.75">Slow</option>
          <option value="1" selected>Normal</option>
          <option value="1.5">Fast</option>
          <option value="2.0">Faster</option>
        </select>
      </div>

      <div class="flex flex-col gap-0.5 text-sm text-gray-600 tabular-nums">
        <span class="text-[10px] font-semibold uppercase tracking-wide text-gray-400">Audio</span>
        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <span class="inline-block min-w-[11rem]">
            <strong class="text-gray-900">Current:</strong>
            {{ playerTimeMs() }} ms <span class="text-[10px] text-gray-400">({{ (currentTimestamp / 1000).toFixed(2) }} s)</span>
          </span>
          <span class="inline-block min-w-[10rem]">
            <strong class="text-gray-900">Duration:</strong>
            <template v-if="durationMs() !== null">{{ durationMs() }} ms <span class="text-[10px] text-gray-400">({{ formatClock(durationMs()) }})</span></template>
            <template v-else>—</template>
          </span>
        </div>
      </div>

      <div class="flex flex-col gap-0.5 text-sm text-gray-600 tabular-nums">
        <span class="text-[10px] font-semibold uppercase tracking-wide text-gray-400">Current ayah</span>
        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <span class="inline-block min-w-[9rem]">
            <strong class="text-gray-900">Elapsed:</strong>
            {{ elapsedMs() }} ms <span class="text-[10px] text-gray-400">({{ formatClock(elapsedMs()) }})</span>
          </span>
          <span class="inline-block min-w-[8.5rem]">
            <strong class="text-gray-900">Length:</strong>
            {{ (ayahDurationMs() / 1000).toFixed(2) }} s <span class="text-[10px] text-gray-400">({{ ayahDurationMs() }} ms)</span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import {mapState, mapGetters} from "vuex";
import hotkeys from "hotkeys-js";
import {playAyah} from "../helper/audio";
import Timeline from "./Timeline.vue";

export default {
  name: "ActionBar",
  components: { Timeline },
  mounted() {
    hotkeys.filter = function (event) {
      return true;
    }
    hotkeys("space, left, right, z, x, s, f, n, a, d", (event, handler) => {
      if (this.disableHotkeys)
        return
      switch (handler.key) {
        case "space":
          this.togglePlay();
          break;
        case "left":
          this.stepBack();
          break;
        case "right":
          this.stepUp();
          break;
        case "z":
          this.markAyahStart();
          break;
        case "x":
          this.markAyahEnd();
          break;
        case "d":
          this.$store.commit("CHANGE_AYAH", {step: 1});
          break;
        case "a":
          this.$store.commit("CHANGE_AYAH", {step: -1});
          break;
        case "s":
          if (this.playbackSpeed > 0.5)
            this.$store.commit("SET_PLAYBACK_SPEED", {
              value: this.playbackSpeed - 0.3,
            });

          break;
        case "f":
          if (this.playbackSpeed < 2)
            this.$store.commit("SET_PLAYBACK_SPEED", {
              value: this.playbackSpeed + 0.3,
            });

          break;
        case "n":
          this.$store.commit("SET_PLAYBACK_SPEED", {value: 1});
          break;
      }

      return false;
    });

    hotkeys("ctrl+z, command+z, ctrl+shift+z, command+shift+z, ctrl+y", (event, handler) => {
      if (this.disableHotkeys) return;

      const el = document.activeElement;
      const tag = el && el.tagName;
      // let the browser handle undo while typing in a field
      if (tag === "INPUT" || tag === "TEXTAREA" || (el && el.isContentEditable)) return;

      event.preventDefault();

      if (handler.key === "ctrl+z" || handler.key === "command+z") {
        this.$store.commit("UNDO_SEGMENTS");
      } else {
        this.$store.commit("REDO_SEGMENTS");
      }

      return false;
    });
  },
  data() {
    return {
      stepDuration: 10,
    };
  },
  watch: {
    stepDuration(value, oldValue) {
      this.$store.commit("SET_STEP_DURATION", {value: value});
    },
    versesCount() {
      this.$nextTick(() => this.initAyahSelect());
    },
    currentVerseNumber() {
      this.syncAyahSelect();
    },
  },
  computed: {
    ...mapState([
      "currentTimestamp",
      "audioSrc",
      "playRangeStart",
      "playRangeEnd",
      "playing",
      "isLooingAyah",
      "stepDuration",
      "segmentChanged",
      "currentAyahTimeFrom",
      "currentAyahTimeTo",
      "verseOriginalSegment",
      "autoSave",
      "currentVerseNumber",
      "versesCount",
      "editMode",
      "playbackSpeed",
      "segmentLocked",
      "audioType",
      "lockAyah",
      "disableHotkeys",
      "showSegments",
      "showTimeline",
      "autoScroll"
    ]),

    disablePlay() {
      if (!!this.audioSrc) return false;

      return true;
    },
    disablePause() {
      if (!!this.audioSrc) return !this.playing;

      return true;
    },
    disableSaveAyahBtn() {
      return this.segmentLocked || !this.segmentChanged;
    },
  },
  methods: {
    playRangeStartChanged(event) {
      this.$store.commit("SET_PLAY_RANGE_START", {value: event.target.value});
    },
    playRangeEndChanged(event) {
      this.$store.commit("SET_PLAY_RANGE_END", {value: event.target.value});
    },
    playRange() {
      this.$store.commit("PLAY_RANGE");
    },
    clearPlayRange() {
      this.$store.commit("CLEAR_PLAY_RANGE");
    },
    currentAyahTimeToChanged(event) {
      const value = Number(event.target.value);
      this.$store.commit("SEGMENT_END_CHANGED", {value: value});
    },
    updatePlaybackSpeed(event) {
      const value = Number(event.target.value);
      this.$store.commit("SET_PLAYBACK_SPEED", {value: value});
    },
    currentAyahTimeFromChanged(event) {
      const value = Number(event.target.value);
      this.$store.commit("SEGMENT_START_CHANGED", {value: value});
    },
    saveAyahSegment() {
      if (this.segmentLocked) {
        this.$store.commit("SET_ALERT", {text: "Sorry segments are locked for this reciter."});
      } else
        this.$store.dispatch("SAVE_AYAH_TIMESTAMP", {
          ayah: this.currentVerseNumber,
        });
    },
    formatClock(ms) {
      const total = Math.floor(Math.max(0, ms) / 1000);
      const minutes = Math.floor(total / 60);
      const seconds = total % 60;

      return `${minutes}:${String(seconds).padStart(2, '0')}`;
    },
    durationMs() {
      if (typeof player === 'undefined' || !player || !isFinite(player.duration) || player.duration <= 0) {
        return null;
      }

      return Math.round(player.duration * 1000);
    },
    elapsedMs() {
      return Math.max(0, Math.round(this.currentTimestamp - this.currentAyahTimeFrom));
    },
    playerTimeMs() {
      return Math.max(0, Math.round(this.currentTimestamp));
    },
    ayahDurationMs() {
      return Math.max(0, Math.round(this.currentAyahTimeTo - this.currentAyahTimeFrom));
    },
    changeAyah(event) {
      this.$store.commit("CHANGE_AYAH", {step: event.target.dataset.step});
    },
    selectAyah(event) {
      if (!event.target.value) return;
      this.$store.commit("CHANGE_AYAH", {to: event.target.value});
    },
    initAyahSelect() {
      const el = this.$refs.ayahSelect;
      if (!el || this._ayahSelectReady || !this.versesCount) return;
      if (!window.$ || !window.$.fn || !window.$.fn.select2) return;

      this._ayahSelectReady = true;
      $(el).select2({
        width: '5rem',
        minimumResultsForSearch: 0,
        containerCssClass: 'segments-ayah-select',
        dropdownCssClass: 'segments-ayah-select-dropdown',
      });

      // select2 fires change via jQuery, which Vue's @change does not receive,
      // so navigate from its own event instead.
      $(el).on('select2:select', (event) => {
        this.$store.commit('CHANGE_AYAH', {to: event.params.data.id});
      });

      this.syncAyahSelect();
    },
    syncAyahSelect() {
      const el = this.$refs.ayahSelect;
      if (!el || !this._ayahSelectReady) return;

      $(el).val(String(this.currentVerseNumber)).trigger('change.select2');
    },
    toggleAutoscroll() {
      this.$store.commit("TOGGLE_AUTOSCROLL");
    },
    toggleHotkeys() {
      this.$store.commit("TOGGLE_HOTKEYS");
    },
    toggleSegment() {
      this.$store.commit("TOGGLE_SEGMENTS");
    },
    toggleTimeline() {
      this.$store.commit("TOGGLE_TIMELINE");
    },
    togglePlay() {
      if (player.paused)
        playAyah();
      else
        player.pause();
    },
    markAyahStart() {
      if (this.editMode) {
        this.$store.commit("MARK_AYAH_START", {
          value: player.currentTime * 1000,
        });
      }
    },
    markAyahEnd() {
      if (this.editMode) {
        this.$store.commit("MARK_AYAH_END", {
          value: player.currentTime * 1000,
        });
      }
    },
    loopAyah() {
      if (player.paused) playAyah();
      this.$store.commit("TOGGLE_LOOP_AYAH");
    },
    stepUp() {
      player.currentTime += this.stepDuration / 1000;
      this.$store.commit("SET_ALERT", {text: `Forward ${this.stepDuration / 1000} seconds`});
    },
    stepBack() {
      player.currentTime -= this.stepDuration / 1000;
      this.$store.commit("SET_ALERT", {text: `Backward ${this.stepDuration / 1000} seconds`});
    },
    changeAutoSave(event) {
      this.$store.commit("SET_AUTO_SAVE", {value: event.target.checked});
    },
    changeEditMode(event) {
      this.$store.commit("SET_EDIT_MODE", {value: event.target.checked});
    },
    toggleLockAyah(event) {
      this.$store.commit("SET_AYAH_LOCK", {value: event.target.checked});
    }
  },
};
</script>

<style>
.segments-ayah-select.select2-container .select2-selection--single {
  height: 26px;
  display: flex;
  align-items: center;
  border-color: #d1d5db;
  border-radius: 0.375rem;
}

.segments-ayah-select.select2-container .select2-selection__rendered {
  font-size: 0.875rem;
  font-weight: 400;
  line-height: 1.25rem;
  color: #374151;
  padding-left: 0.5rem;
}

.segments-ayah-select.select2-container .select2-selection__arrow {
  height: 24px;
}

.segments-ayah-select-dropdown .select2-results__option,
.segments-ayah-select-dropdown .select2-search__field {
  font-size: 0.875rem;
  font-weight: 400;
}
</style>

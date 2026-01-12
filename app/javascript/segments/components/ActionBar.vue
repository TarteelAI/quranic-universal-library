<template>
  <div class="tw-flex tw-flex-wrap tw-my-2">
    <div class="tw-w-full tw-flex tw-flex-wrap tw-items-start tw-gap-4">
      <div class="tw-flex tw-flex-col tw-gap-2">
        <div class="tw-flex tw-gap-1">
          <button
              class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-cyan-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-cyan-700 disabled:tw-opacity-50"
              data-step="-1"
              @click="changeAyah"
              :disabled="currentVerseNumber <= 1"
          >
            Previous ayah
          </button>
          <button
              class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-cyan-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-cyan-700 disabled:tw-opacity-50"
              data-step="1"
              @click="changeAyah"
              :disabled="currentVerseNumber >= versesCount"
          >
            Next ayah
          </button>
        </div>

        <div class="tw-flex tw-flex-wrap tw-gap-x-4 tw-gap-y-1">
          <div class="tw-flex tw-items-center">
            <input
                type="checkbox"
                :checked="disableHotkeys"
                @change="toggleHotkeys"
                id="toggle-hotkeys"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="toggle-hotkeys"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   data-controller="tooltip"
                   title="Toggle hotkeys">
              Disable Hotkeys
            </label>
          </div>

          <div class="tw-flex tw-items-center">
            <input
                type="checkbox"
                :checked="showSegments"
                @change="toggleSegment"
                id="toggle-segments"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="toggle-segments"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   title="Toggle segments table.">
              Segments
            </label>
          </div>

          <div class="tw-flex tw-items-center">
            <input
                type="checkbox"
                :checked="autoScroll"
                @change="toggleAutoscroll"
                id="toggle-scroll"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="toggle-scroll"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   data-controller="tooltip"
                   title="Autoscroll segments table to current word">
              Autoscroll
            </label>
          </div>
        </div>
      </div>

      <div class="tw-flex tw-gap-1">
        <button
            class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-blue-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-blue-700 disabled:tw-opacity-50"
            @click="togglePlay"
            :disabled="disablePlay"
        >
          {{ playing ? "Pause" : "Play" }}
        </button>
        <button
            class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-blue-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-blue-700"
            @click="loopAyah"
        >
          {{ isLooingAyah ? "Looping" : "Loop" }}
        </button>
      </div>

      <div class="tw-flex tw-flex-col tw-gap-1">
        <div class="tw-flex tw-gap-1">
          <button class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-blue-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-blue-700" @click="stepUp">Forward</button>
          <button class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-blue-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-blue-700" @click="stepBack">Backward</button>
        </div>
        <div>
          <input
              type="number"
              v-model="stepDuration"
              placeholder="step duration"
              class="tw-w-24 tw-px-2 tw-py-1 tw-text-xs tw-border tw-border-gray-300 tw-rounded-md tw-focus:tw-outline-none tw-focus:tw-ring-2 tw-focus:tw-ring-blue-500"
          />
        </div>
      </div>

      <div class="tw-flex tw-flex-col tw-gap-2 tw-ml-auto">
        <div class="tw-flex tw-flex-wrap tw-gap-x-4 tw-gap-y-1">
          <div class="tw-flex tw-items-center">
            <input
                type="checkbox"
                :checked="lockAyah"
                @change="toggleLockAyah"
                id="lock-ayah"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="lock-ayah"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   data-controller="tooltip"
                   title="If checked, player will not play the next ayah when current ayah is finished.">
              Lock ayah
            </label>
          </div>

          <div class="tw-flex tw-items-center">
            <input
                type="checkbox"
                :checked="editMode"
                @change="changeEditMode"
                id="edit-mode"
                :disabled="segmentLocked"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="edit-mode"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   data-controller="tooltip"
                   title="Check this if you need to update the ayah timing when you click ayah start or end button. Clicking ayah end will also set start time of next ayah.">
              Update Ayah timing
            </label>
          </div>

          <div class="tw-flex tw-items-center" v-if="editMode">
            <input
                type="checkbox"
                :checked="autoSave"
                @change="changeAutoSave"
                id="auto-save"
                :disabled="segmentLocked"
                class="tw-w-4 tw-h-4 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500"
            />
            <label for="auto-save"
                   class="tw-ml-2 tw-text-sm tw-text-gray-700"
                   data-controller="tooltip"
                   title="Auto save will automatically save ayah the segment timestamps.">
              Auto Save
            </label>
          </div>
        </div>

        <div class="tw-flex tw-items-center tw-gap-2">
          <div v-if="editMode && audioType == 'chapter'" class="tw-flex tw-gap-1">
            <button
                class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-red-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-red-700 disabled:tw-opacity-50"
                @click="markAyahStart"
                :disabled="segmentLocked">
              Start
            </button>

            <button
                class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-red-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-red-700 disabled:tw-opacity-50"
                @click="markAyahEnd"
                :disabled="segmentLocked">
              End
            </button>
          </div>

          <button
              class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-green-600 tw-text-white tw-rounded tw-transition-colors hover:tw-bg-green-700 disabled:tw-opacity-50"
              @click="saveAyahSegment"
              :disabled="disableSaveAyahBtn"
          >
            Save ayah
          </button>
        </div>

        <div class="tw-flex tw-gap-2">
          <div class="tw-flex tw-flex-col">
            <input
                type="number"
                placeholder="From"
                ref="ayahTimeFromInput"
                :value="currentAyahTimeFrom"
                class="tw-w-24 tw-px-2 tw-py-1 tw-text-xs tw-border tw-border-gray-300 tw-rounded-md tw-focus:tw-outline-none tw-focus:tw-ring-2 tw-focus:tw-ring-blue-500"
                :disabled="segmentLocked"
                @change="currentAyahTimeFromChanged"
            />
            <small class="tw-text-xs tw-text-gray-500" v-if="!!verseOriginalSegment">{{
                verseOriginalSegment.timestamp_from
              }}</small>
          </div>

          <div class="tw-flex tw-flex-col">
            <input
                type="number"
                placeholder="to"
                ref="ayahTimeToInput"
                :disabled="segmentLocked"
                :value="currentAyahTimeTo"
                class="tw-w-24 tw-px-2 tw-py-1 tw-text-xs tw-border tw-border-gray-300 tw-rounded-md tw-focus:tw-outline-none tw-focus:tw-ring-2 tw-focus:tw-ring-blue-500"
                @change="currentAyahTimeToChanged"
            />
            <small class="tw-text-xs tw-text-gray-500" v-if="!!verseOriginalSegment">{{
                verseOriginalSegment.timestamp_to
              }}</small>
          </div>
        </div>
      </div>
    </div>

    <div class="tw-w-full tw-flex tw-flex-wrap tw-items-center tw-gap-6 tw-my-6 tw-p-4 tw-bg-gray-50 tw-rounded-lg">
      <div class="tw-flex tw-items-center tw-gap-2">
        <span class="tw-text-sm tw-font-medium tw-text-gray-700">Speed:</span>
        <select @change="updatePlaybackSpeed" class="tw-text-sm tw-border tw-border-gray-300 tw-rounded tw-px-2 tw-py-0.5 tw-bg-white focus:tw-outline-none focus:tw-ring-1 focus:tw-ring-blue-500">
          <option value="0.3">Slowest</option>
          <option value="0.5">Slower</option>
          <option value="0.75">Slow</option>
          <option value="1" selected>Normal</option>
          <option value="1.5">Fast</option>
          <option value="2.0">Faster</option>
        </select>
      </div>
      
      <div class="tw-flex tw-gap-4 tw-text-sm tw-text-gray-600">
        <span><strong class="tw-text-gray-900">Duration:</strong> {{ totalDuration() }} ms</span>
        <span><strong class="tw-text-gray-900">Current:</strong> {{ currentTime() }}</span>
        <span><strong class="tw-text-gray-900">Elapsed:</strong> {{ elapsedTime() }}</span>
        <span><strong class="tw-text-gray-900">Remaining:</strong> {{ remainingTime() }}</span>
      </div>

      <div class="tw-grow tw-min-w-[200px]" v-if="audioType == 'chapter'">
        <Slider
            v-model="sliderRange"
            keyboardSupport="true"
            keyboardDefaultStep="10"
            :min="sliderMaxRange[0]"
            :max="sliderMaxRange[1]"
            :options="sliderOptions"
            :disabled="segmentLocked"
        />
      </div>
    </div>
  </div>
</template>

<script>
import {mapState, mapGetters} from "vuex";
import "@vueform/slider/themes/default.css";
import Slider from "@vueform/slider";
import hotkeys from "hotkeys-js";
import {playAyah} from "../helper/audio";

export default {
  name: "ActionBar",
  components: {
    Slider,
  },
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
  },
  data() {
    return {
      stepDuration: 10,
      sliderRange: [0, 0],
      sliderOptions: {
        pips: {
          mode: "range",
          density: 5,
        },
      },
    };
  },
  watch: {
    stepDuration(value, oldValue) {
      this.$store.commit("SET_STEP_DURATION", {value: value});
    },
    sliderRange(value, oldValue) {
      if (this.sliderLoaded) {
        this.updateCurrentAyahTime(value);
      }
    },
  },
  computed: {
    ...mapState([
      "currentTimestamp",
      "audioSrc",
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
      "autoScroll"
    ]),

    disablePlay() {
      if (!!this.audioSrc) return false;

      return true;
    },
    sliderMaxRange() {
      this.sliderRange = [this.currentAyahTimeFrom, this.currentAyahTimeTo];
      this.sliderLoaded = true;
      const offset = (this.currentAyahTimeTo - this.currentAyahTimeFrom) / 4;

      return [
        this.currentAyahTimeFrom - offset,
        this.currentAyahTimeTo + offset,
      ];
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
    updateCurrentAyahTime(value) {
      if (this.$refs.ayahTimeFromInput) {
        this.$refs.ayahTimeFromInput.value = value[0];
        this.$store.commit("SEGMENT_START_CHANGED", {value: value[0]});
      }

      if (this.$refs.ayahTimeToInput) {
        this.$refs.ayahTimeToInput.value = value[1];
        this.$store.commit("SEGMENT_END_CHANGED", {value: value[1]});
      }
    },
    saveAyahSegment() {
      if (this.segmentLocked) {
        this.$store.commit("SET_ALERT", {text: "Sorry segments are locked for this reciter."});
      } else
        this.$store.dispatch("SAVE_AYAH_TIMESTAMP", {
          ayah: this.currentVerseNumber,
        });
    },
    currentTime() {
      return this.currentTimestamp.toFixed(2);
    },
    remainingTime() {
      return (this.currentAyahTimeTo - this.currentTimestamp).toFixed(3);
    },
    elapsedTime() {
      return (this.currentTimestamp - this.currentAyahTimeFrom).toFixed(3);
    },
    totalDuration() {
      return this.currentAyahTimeTo - this.currentAyahTimeFrom;
    },
    changeAyah(event) {
      this.$store.commit("CHANGE_AYAH", {step: event.target.dataset.step});
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
.slider-pips-horizontal {
  padding: 10px 0;
  height: 80px;
  top: 100%;
  left: 0;
  width: 100%;
  position: absolute;
  color: #999;
}

.slider-pips-horizontal * {
  box-sizing: border-box;
}

.slider-marker-horizontal {
  margin-left: -1px;
  width: 2px;
  position: absolute;
  background: #ccc;
}

.slider-marker-normal {
  height: 5px;
}

.slider-marker-large {
  height: 15px;
  background: #aaa;
}

.slider-value {
  position: absolute;
  white-space: nowrap;
  text-align: center;
  transform: translate(-50%, 50%);
}

.slider-value-large {
}
</style>

<template>
  <div class="flex flex-wrap">
    <div class="w-full" v-if="segmentsLoaded">
      <div class="text-xl font-bold mb-4 flex items-center gap-4">
        <span>Current Ayah {{ currentVerseKey }}</span>

        <select @change="changeAyah" class="text-sm border border-gray-300 rounded px-2 py-1 bg-white focus:outline-none focus:ring-1 focus:ring-blue-500">
          <option
            v-for="(num, index) in Array.from(
              { length: versesCount },
              (_, i) => i + 1
            )"
            :key="index"
            :selected="num == currentVerseNumber"
          >
            {{ num }}
          </option>
        </select>
      </div>

      <div class="qpc-hafs flex flex-wrap gap-2 p-4 bg-gray-50 rounded-lg mb-6 sticky top-0 z-50 shadow-sm words">
        <span
          :id="index + 1"
          :class="[this.getWordCssClass(index)]"
          v-for="(text, index) in wordsText"
          :key="index"
          title="Repeat word"
          @click="showWordPopover"
          class="px-2 py-1 border border-dotted border-green-600 rounded cursor-pointer transition-colors"
        >
          {{ text }}
        </span>
      </div>

      <div v-if="shouldShowSegment">
        <h4 class="flex justify-between items-center mt-8 mb-4">
          <div class="flex items-center gap-3">
            <span class="text-lg font-semibold">Segments</span>

            <span
                v-if="saving"
                class="flex items-center gap-1 px-2 py-0.5 text-[11px] font-medium bg-blue-100 text-blue-800 rounded-full"
            >
              <span class="inline-block w-3 h-3 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></span>
              Saving…
            </span>
            <span
                v-else-if="segmentsUnsaved"
                class="px-2 py-0.5 text-[11px] font-medium bg-red-100 text-red-600 rounded-full"
            >
              Has unsaved changes
            </span>
            <span
                v-else-if="segmentsSaved"
                class="px-2 py-0.5 text-[11px] font-medium bg-green-100 text-green-800 rounded-full"
            >
              All changes saved
            </span>
          </div>

          <div class="flex items-center gap-2">
            <label
                class="flex items-center gap-1 text-xs text-gray-700 mr-1"
                data-controller="tooltip"
                title="Automatically save the word segments when moving to the next or previous ayah, if there are unsaved changes."
            >
              <input
                  type="checkbox"
                  :checked="autoSaveSegments"
                  @change="changeAutoSaveSegments"
                  :disabled="segmentLocked"
                  class="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              Auto save
            </label>

            <button
                @click="showRawSegment"
                :disabled="segmentLocked"
                class="px-3 py-1 text-xs font-medium bg-cyan-600 text-white rounded hover:bg-cyan-700 disabled:opacity-50"
            >
              Show raw segments
            </button>

            <button
                @click="toggleSegmentTiming"
                :disabled="segmentLocked"
                class="px-3 py-1 text-xs font-medium bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
                :class="{ 'hidden': segmentLocked }"
            >
              {{this.verseSegment.segments[0].length > 1 ? 'Clear Segment' : 'Reload Segments'}}
            </button>

            <button
                @click="saveAyahSegment"
                :disabled="segmentLocked"
                class="px-3 py-1 text-xs font-medium bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50"
                :class="{ 'hidden': segmentLocked }"
            >
              Save Segments
            </button>
          </div>
        </h4>

        <div class="flex flex-wrap gap-4 mb-3 text-xs text-gray-500">
          <span class="flex items-center gap-1">
            <span class="inline-block w-4 h-4 rounded-sm bg-yellow-100 border border-yellow-300"></span>
            Segment issue
          </span>
          <span class="flex items-center gap-1">
            <span class="inline-block w-4 h-4 rounded-sm bg-blue-50 border border-blue-200"></span>
            Unsaved changes
          </span>
          <span class="flex items-center gap-1">
            <span class="inline-block w-4 h-4 rounded-sm bg-green-50 border border-green-200"></span>
            Current word
          </span>
        </div>

        <div v-if="rawSegmentVisible" class="mt-3">
          <textarea
              class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              @input="updateRawSegments"
          ></textarea>
        </div>
        <div class="text-xs text-gray-500 mb-2" v-if="rawSegments[currentVerseNumber]">
          {{ JSON.stringify(rawSegments[currentVerseNumber]) }}
        </div>

        <div class="overflow-x-auto border border-gray-200 rounded-lg" id="tableWrapper">
          <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 sticky top-0 z-10">
              <tr>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b">Word</th>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b">Text</th>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b">Start</th>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b">Ends</th>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b text-center">Pause</th>
                <th class="px-4 py-2 text-xs font-semibold text-gray-600 border-b">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr
                :id="[`word-${segment[0]}-${index}`]"
                :class="segmentRowClass(segment, index)"
                v-for="(segment, index) in verseSegment.segments"
                :key="index"
                :data-index="index"
                :data-word="segment[0]"
                class="hover:bg-gray-50 transition-colors"
              >
                <td class="px-4 py-2">
                  <input
                    type="number"
                    min="1"
                    :value="segment[0]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentNumber"
                    class="w-16 px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                  <small class="block text-[10px] text-gray-400 mt-0.5">
                    <span>{{ segment[0] }} </span>
                  </small>
                </td>

                <td class="px-4  py-2 text-lg qpc-hafs">
                  {{ segmentText(segment) }}
                  <small class="block text-[10px] text-gray-400 mt-0.5" v-if="segmentDuration(segment)">
                    {{ segmentDuration(segment) }}
                  </small>
                </td>
                <td class="px-4 py-2 w-48">
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      @click="adjustSegmentTime(index, 1, -timeStep)"
                      :disabled="segmentLocked"
                      :title="`-${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      −
                    </button>
                    <input
                      type="number"
                      min="0"
                      :id="[`start-${segment[0]}-${index}`]"
                      :value="segment[1]"
                      :data-index="index"
                      :disabled="segmentLocked"
                      @change="updateSegmentStart"
                      class="flex-1 min-w-0 px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                    <button
                      type="button"
                      @click="adjustSegmentTime(index, 1, timeStep)"
                      :disabled="segmentLocked"
                      :title="`+${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      +
                    </button>
                  </div>
                  <small class="flex justify-between text-[10px] text-gray-400 mt-0.5">
                    <span>
                      {{ segmentOriginalStart(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment start">
                      {{ rawSegmentStart(index) }}
                    </span>
                  </small>
                </td>

                <td class="px-4 py-2 w-48">
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      @click="adjustSegmentTime(index, 2, -timeStep)"
                      :disabled="segmentLocked"
                      :title="`-${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      −
                    </button>
                    <input
                      type="number"
                      min="0"
                      :value="segment[2]"
                      :id="[`end-${segment[0]}-${index}`]"
                      :data-index="index"
                      :disabled="segmentLocked"
                      @change="updateSegmentEnd"
                      class="flex-1 min-w-0 px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                    <button
                      type="button"
                      @click="adjustSegmentTime(index, 2, timeStep)"
                      :disabled="segmentLocked"
                      :title="`+${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      +
                    </button>
                  </div>
                  <small class="flex justify-between text-[10px] text-gray-400 mt-0.5">
                    <span>
                      {{ segmentOriginalEnd(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment end">
                      {{rawSegmentEnd(index)}}
                    </span>
                  </small>
                </td>

              <td class="px-4 py-2 text-center">
                <input
                    type="checkbox"
                    :checked="hasWaqaf(segment)"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="toggleWaqaf"
                    class="w-5 h-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer"
                    title="Check if Qari has taken a waqf after this word"
                    data-controller="tooltip"
                    name="waqf"
                    :id="[`waqf-${index}`]"
                />
                <small class="block text-xs text-gray-500 mt-0.5">
                  {{ hasWaqaf(segment) ? 'وقف' : '' }}
                </small>
              </td>

              <td class="px-4 py-2" :data-word="segment[0]" :data-index="index">
                <div
                    class="flex flex-wrap gap-1"
                    :data-word="segment[0]" :data-index="index"
                >
                  <button
                      @click="insertSegment"
                      class="px-2 py-1 text-[10px] font-medium bg-cyan-600 text-white rounded hover:bg-cyan-700 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                    >
                      Add
                    </button>
                    <button
                      @click="removeSegment"
                      class="px-2 py-1 text-[10px] font-medium bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                    >
                      Remove
                    </button>

                    <button @click="playWord" class="px-2 py-1 text-[10px] font-medium bg-gray-600 text-white rounded hover:bg-gray-700">
                      {{ playingWord == index + 1 ? 'Playing' : 'Play' }}
                    </button>

                    <button
                      @click="loopWord"
                      class="px-2 py-1 text-[10px] font-medium bg-gray-600 text-white rounded hover:bg-gray-700"
                    >
                      {{ loopingWord == index + 1 ? 'Looping' : 'Loop' }}
                    </button>

                    <button
                      @click="trackTime"
                      class="px-2 py-1 text-[10px] font-medium bg-yellow-500 text-white rounded hover:bg-yellow-600 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                    >
                      Track
                    </button>

                    <button
                      v-if="canSplit(index)"
                      @click="splitSegment"
                      class="px-2 py-1 text-[10px] font-medium bg-purple-600 text-white rounded hover:bg-purple-700 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                      title="Divide this word's timing with the following words that have no timing"
                      data-controller="tooltip"
                    >
                      Split
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapState } from 'vuex';
import {playAyah} from "../helper/audio";
import {hasTiming} from "../helper/segmentTime";

export default {
  name: 'Verse',
  data() {
    return {
      timeStep: 50,
    };
  },
  created() {
    window.store = this.$store;

    this.unwatch = this.$store.watch(
      (state) => state.currentWord,
      (newValue, _) => {
        //const row = window[`word${newValue}`];
        //if (row) row.scrollIntoView(false, { behavior: "instant" });
      }
    );

    this.unwatchWord = this.$store.watch(
        (state, getters) => state.wordLoopTime,

        (newValue, _) => {
          if (newValue >= 0) {
            player.currentTime = newValue / 1000;
          }
        }
    );

    addEventListener(
      'click',
      (e) => {
        const target = e.target;

        if (target.getAttribute('data-action') == 'repeat-group') {
          this.insertRepeatGroupSegment(Number(target.dataset.word));

          if (window.popover) {
            window.popover.dispose();
            window.popover = null;
          }
        }
      },
      false
    );
  },
  beforeDestroy() {
    this.unwatch();
  },
  methods: {
    hasWaqaf(segment) {
      return segment[3] && segment[3].waqaf === true;
    },
    toggleWaqaf(event) {
      const target = event.target;
      const { index } = target.dataset;

      this.$store.commit('TRACK_SEG_WAQAF', {
        waqaf: target.checked,
        index: Number(index),
      });
    },
    getWordCssClass(index) {
      let cssClasses = 'word';

      if (index + 1 == this.currentWord) {
        cssClasses += ' active';
      }

      if(index + 1 === this.currentRawSegmentWord){
        cssClasses += ' text-danger';
      }

      if (this.repeatGroups.includes(index + 1)) {
        cssClasses += ' bg-info';
      }

      return cssClasses;
    },
    insertRepeatGroupSegment(word) {
      const lastRepeatWord = this.repeatGroups[this.repeatGroups.length - 1];

      if (this.repeatGroups.includes(word) || lastRepeatWord > word) {
        this.$store.commit('SET_ALERT', {
          text: "Sorry can't add repeat group after this word, it already have a repeated group.",
        });
        return;
      }

      this.$store.commit('INSERT_REPEAT_SEG_AFTER', { word });
    },
    insertSegment(event) {
      const target = event.target;
      const { word, index } = target.parentElement.dataset;
      this.$store.commit('INSERT_SEG_AFTER', {
        word,
        index: Number(index) + 1,
      });
    },
    removeSegment(event) {
      const target = event.target;
      const { index } = target.parentElement.dataset;

      if (confirm('Are you sure to remove this segment?')) {
        this.$store.commit('REMOVE_SEGMENT', {
          index: Number(index),
        });
      }
    },
    saveAyahSegment(event) {
      if (this.segmentLocked) {
        this.$store.commit('SET_ALERT', {
          text: 'Sorry segments are locked for this reciter.',
        });
      } else this.$store.dispatch('SAVE_AYAH_SEGMENTS');
    },
    toggleSegmentTiming(event){
      if(this.verseSegment.segments[0].length == 1){
        this.$store.commit('RELOAD_SEGMENTS');
      } else{
        this.$store.commit('CLEAR_SEGMENTS');
      }
    },
    showRawSegment(event) {
      this.$store.commit('SHOW_RAW_SEGMENT');
    },
    showWordPopover(event) {
      const target = event.target;
      if (this.segmentLocked) return;

      if (target.hasPopover) {
        target.hasPopover = false;
      } else {
        const content = `<button data-word=${target.id} data-action=repeat-group>Repeat segments</button>`;
        target.hasPopover = true;

        let a = $(event.target).popover({
          title: target.textContent,
          content: content,
          html: true,
          sanitize: false,
        });
      }
    },
    updateSegmentStart(event) {
      const target = event.target;
      const { index } = target.dataset;

      this.$store.commit('TRACK_SEG_START', {
        time: target.value,
        index: index,
      });

      // refresh
      this.$store.state.showSegments = false;
      this.$store.state.showSegments = true;
    },
    updateSegmentEnd(event) {
      const target = event.target;
      const { index } = target.dataset;

      this.$store.commit('TRACK_SEG_END', {
        time: target.value,
        index: index,
      });

      // refresh
      this.$store.state.showSegments = false;
      this.$store.state.showSegments = true;
    },
    segmentOriginalStart(index) {
      const segment = this.verseOriginalSegment.segments[index];
      if (segment) return segment[1];
    },
    segmentOriginalEnd(index) {
      const segment = this.verseOriginalSegment.segments[index];
      if (segment) return segment[2];
    },
    rawSegmentStart(index) {
      const segment = this.rawSegments[this.currentVerseNumber];
      if (segment && segment[index]) return segment[index][1];
    },
    rawSegmentEnd(index) {
      const segment = this.rawSegments[this.currentVerseNumber];
      if (segment && segment[index]) return segment[index][2];
    },
    segmentText(segment) {
      return this.wordsText[segment[0] - 1];
    },
    segmentDuration(segment) {
      const start = Number(segment[1]);
      const end = Number(segment[2]);
      if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return '';

      return `${((end - start) / 1000).toFixed(2)}s`;
    },
    segmentChanged(segment, index) {
      const original = this.loadedSegments[index];
      if (!original) return false;

      const time = (value) => (value === undefined || value === null || value === '') ? null : Number(value);
      const waqaf = (s) => !!(s[3] && s[3].waqaf);

      return time(segment[0]) !== time(original[0]) ||
        time(segment[1]) !== time(original[1]) ||
        time(segment[2]) !== time(original[2]) ||
        waqaf(segment) !== waqaf(original);
    },
    segmentHasIssue(segment) {
      if (!hasTiming(segment)) return true;
      return Number(segment[1]) >= Number(segment[2]);
    },
    segmentRowClass(segment, index) {
      const current = index + 1 == this.currentWord;

      if (this.segmentHasIssue(segment)) return ['bg-yellow-100'];
      if (this.segmentChanged(segment, index)) return ['bg-blue-50'];
      if (current) return ['bg-green-50'];

      return [];
    },
    canSplit(index) {
      const segments = this.verseSegment.segments;
      const segment = segments[index];
      if (!segment || !hasTiming(segment)) return false;

      const next = segments[index + 1];
      return !!next && !hasTiming(next);
    },
    splitSegment(event) {
      const { index } = event.target.parentElement.dataset;

      this.$store.commit('SPLIT_SEGMENT_TIME', {
        index: Number(index),
      });

      // refresh
      this.$store.state.showSegments = false;
      this.$store.state.showSegments = true;
    },
    adjustSegmentTime(index, field, delta) {
      this.$store.commit('ADJUST_SEG_TIME', {
        index: index,
        field: field,
        delta: delta,
      });
    },
    changeAyah(event) {
      this.$store.commit('CHANGE_AYAH', { to: event.target.value });
    },
    changeAutoSaveSegments(event) {
      this.$store.commit('SET_AUTO_SAVE_SEGMENTS', { value: event.target.checked });
    },
    loopWord(event) {
      this.$store.commit('TOGGLE_LOOP_WORD', {
        word: event.target.parentNode.parentNode.dataset.word,
      });

      if (player.paused) playAyah();
    },
    playWord(event) {
      const { index } = event.target.parentElement.dataset;

      this.$store.commit('PLAY_WORD', {
        index: Number(index),
      });
    },
    updateSegmentNumber(event) {
      const target = event.target;
      const { index } = target.dataset;

      this.$store.commit('SET_SEG_WORD_NUMBER', {
        word: target.value,
        index: index,
      });
    },
    updateRawSegments(event) {
      try {
        const data =  event.target.value
            .replace(/(\d+):/g, '"$1":')
            .replace(/\s+/g, '');
        const segs = JSON.parse(data);
        this.$store.commit('UPDATE_RAW_SEGMENTS', {
          segments: segs,
        });
      } catch (error) {
        console.error(error)
      }
    },
    trackTime(event) {
      const target = event.target;
      const { word, index } = target.parentElement.dataset;
      const segStart = document.querySelector(`#start-${word}-${index}`);

      if (segStart.value.length == 0) {
        this.$store.commit('TRACK_SEG_START', {
          time: player.currentTime * 1000,
          index: index,
        });
      } else {
        this.$store.commit('TRACK_SEG_END', {
          time: player.currentTime * 1000,
          index: index,
        });

        this.$store.commit('TRACK_SEG_START', {
          time: player.currentTime * 1000,
          index: Number(index) + 1,
        });
      }
    },
  },
  computed: {
    ...mapState([
      'currentVerseKey',
      'wordsText',
      'currentWord',
      'currentRawSegmentWord',
      'loopingWord',
      'playingWord',
      'verseSegment',
      'verseOriginalSegment',
      'showSegments',
      'versesCount',
      'currentVerseNumber',
      'playing',
      'repeatGroups',
      'segmentLocked',
      'audioType',
      'rawSegmentVisible',
      'rawSegments',
      'segmentsUnsaved',
      'segmentsSaved',
      'saving',
      'autoSaveSegments',
      'loadedSegments'
    ]),
    segmentsLoaded() {
      return !!this.verseSegment;
    },
    shouldShowSegment() {
      return this.showSegments && this.segmentsLoaded;
    },
  },
};
</script>

<style scoped>
.active {
  color: #fff;
  background-color: #198754;
}

.active input{
  color: #0a0a0a;
}

.active .form-text {
  color: #fff;
}

.word {
  border: 1px dotted #198754;
  padding: 0 3px;
  margin: 0 2px;
  cursor: pointer;
}

.table-wrapper {
  /*height: 100px !important;
  overflow: scroll;
  scroll-behavior: smooth;*/
}

tr {
  scroll-behavior: smooth;
}

thead {
  position: sticky;
  top: 0;
  background: #fff;
  border: 1px solid #ccc;
  border-collapse: collapse;
}

.words {
  position: sticky;
  top: 0;
  z-index: 100;
  background: #fff;
}
</style>

<template>
  <div class="tw-flex tw-flex-wrap">
    <div class="tw-w-full" v-if="segmentsLoaded">
      <div class="tw-text-xl tw-font-bold tw-mb-4 tw-flex tw-items-center tw-gap-4">
        <span>Current Ayah {{ currentVerseKey }}</span>

        <select @change="changeAyah" class="tw-text-sm tw-border tw-border-gray-300 tw-rounded tw-px-2 tw-py-1 tw-bg-white focus:tw-outline-none focus:tw-ring-1 focus:tw-ring-blue-500">
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

      <div class="qpc-hafs tw-flex tw-flex-wrap tw-gap-2 tw-p-4 tw-bg-gray-50 tw-rounded-lg tw-mb-6 tw-sticky tw-top-0 tw-z-50 tw-shadow-sm words">
        <span
          :id="index + 1"
          :class="[this.getWordCssClass(index)]"
          v-for="(text, index) in wordsText"
          :key="index"
          title="Repeat word"
          @click="showWordPopover"
          class="tw-px-2 tw-py-1 tw-border tw-border-dotted tw-border-green-600 tw-rounded tw-cursor-pointer tw-transition-colors"
        >
          {{ text }}
        </span>
      </div>

      <div v-if="shouldShowSegment">
        <h4 class="tw-flex tw-justify-between tw-items-center tw-mt-8 tw-mb-4">
          <div class="tw-text-lg tw-font-semibold">Segments</div>

          <div class="tw-flex tw-gap-2">
            <button
                @click="showRawSegment"
                :disabled="segmentLocked"
                class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-cyan-600 tw-text-white tw-rounded hover:tw-bg-cyan-700 disabled:tw-opacity-50"
            >
              Show raw segments
            </button>

            <button
                @click="toggleSegmentTiming"
                :disabled="segmentLocked"
                class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-red-600 tw-text-white tw-rounded hover:tw-bg-red-700 disabled:tw-opacity-50"
                :class="{ 'tw-hidden': segmentLocked }"
            >
              {{this.verseSegment.segments[0].length > 1 ? 'Clear Segment' : 'Reload Segments'}}
            </button>

            <button
                @click="saveAyahSegment"
                :disabled="segmentLocked"
                class="tw-px-3 tw-py-1 tw-text-xs tw-font-medium tw-bg-green-600 tw-text-white tw-rounded hover:tw-bg-green-700 disabled:tw-opacity-50"
                :class="{ 'tw-hidden': segmentLocked }"
            >
              Save Segments
            </button>
          </div>
        </h4>

        <div v-if="rawSegmentVisible" class="tw-mt-3">
          <textarea
              class="tw-w-full tw-px-3 tw-py-2 tw-text-sm tw-border tw-border-gray-300 tw-rounded-md tw-focus:tw-outline-none tw-focus:tw-ring-2 tw-focus:tw-ring-blue-500"
              @input="updateRawSegments"
          ></textarea>
        </div>
        <div class="tw-text-xs tw-text-gray-500 tw-mb-2" v-if="rawSegments[currentVerseNumber]">
          {{ JSON.stringify(rawSegments[currentVerseNumber]) }}
        </div>

        <div class="tw-overflow-x-auto tw-border tw-border-gray-200 tw-rounded-lg" id="tableWrapper">
          <table class="tw-w-full tw-text-left tw-border-collapse">
            <thead class="tw-bg-gray-50 tw-sticky tw-top-0 tw-z-10">
              <tr>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b">Word</th>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b">Text</th>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b">Start</th>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b">Ends</th>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b tw-text-center">Pause</th>
                <th class="tw-px-4 tw-py-2 tw-text-xs tw-font-semibold tw-text-gray-600 tw-border-b">Actions</th>
              </tr>
            </thead>
            <tbody class="tw-divide-y tw-divide-gray-100">
              <tr
                :id="[`word-${segment[0]}-${index}`]"
                :class="[index + 1 == currentWord ? 'tw-bg-green-50' : '']"
                v-for="(segment, index) in verseSegment.segments"
                :key="index"
                :data-index="index"
                :data-word="segment[0]"
                class="hover:tw-bg-gray-50 tw-transition-colors"
              >
                <td class="tw-px-4 tw-py-2">
                  <input
                    type="number"
                    min="1"
                    :value="segment[0]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentNumber"
                    class="tw-w-16 tw-px-2 tw-py-1 tw-text-sm tw-border tw-border-gray-300 tw-rounded focus:tw-outline-none focus:tw-ring-1 focus:tw-ring-blue-500"
                  />
                  <small class="tw-block tw-text-[10px] tw-text-gray-400 tw-mt-0.5">
                    <span>{{ segment[0] }} </span>
                  </small>
                </td>

                <td class="tw-px-4  tw-py-2 tw-text-lg qpc-hafs">{{ segmentText(segment) }}</td>
                <td class="tw-px-4 tw-py-2 tw-w-48">
                  <input
                    type="number"
                    min="0"
                    :id="[`start-${segment[0]}-${index}`]"
                    :value="segment[1]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentStart"
                    class="tw-w-full tw-px-2 tw-py-1 tw-text-sm tw-border tw-border-gray-300 tw-rounded focus:tw-outline-none focus:tw-ring-1 focus:tw-ring-blue-500"
                  />
                  <small class="tw-flex tw-justify-between tw-text-[10px] tw-text-gray-400 tw-mt-0.5">
                    <span>
                      {{ segmentOriginalStart(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment start">
                      {{ rawSegmentStart(index) }}
                    </span>
                  </small>
                </td>

                <td class="tw-px-4 tw-py-2 tw-w-48">
                  <input
                    type="number"
                    min="0"
                    :value="segment[2]"
                    :id="[`end-${segment[0]}-${index}`]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentEnd"
                    class="tw-w-full tw-px-2 tw-py-1 tw-text-sm tw-border tw-border-gray-300 tw-rounded focus:tw-outline-none focus:tw-ring-1 focus:tw-ring-blue-500"
                  />
                  <small class="tw-flex tw-justify-between tw-text-[10px] tw-text-gray-400 tw-mt-0.5">
                    <span>
                      {{ segmentOriginalEnd(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment end">
                      {{rawSegmentEnd(index)}}
                    </span>
                  </small>
                </td>

              <td class="tw-px-4 tw-py-2 tw-text-center">
                <input
                    type="checkbox"
                    :checked="hasWaqaf(segment)"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="toggleWaqaf"
                    class="tw-w-5 tw-h-5 tw-rounded tw-border-gray-300 tw-text-blue-600 focus:tw-ring-blue-500 tw-cursor-pointer"
                    title="Check if Qari has taken a waqf after this word"
                    data-controller="tooltip"
                    name="waqf"
                    :id="[`waqf-${index}`]"
                />
                <small class="tw-block tw-text-xs tw-text-gray-500 tw-mt-0.5">
                  {{ hasWaqaf(segment) ? 'وقف' : '' }}
                </small>
              </td>

              <td class="tw-px-4 tw-py-2" :data-word="segment[0]" :data-index="index">
                <div
                    class="tw-flex tw-flex-wrap tw-gap-1"
                    :data-word="segment[0]" :data-index="index"
                >
                  <button
                      @click="insertSegment"
                      class="tw-px-2 tw-py-1 tw-text-[10px] tw-font-medium tw-bg-cyan-600 tw-text-white tw-rounded hover:tw-bg-cyan-700 disabled:tw-opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'tw-hidden': segmentLocked }"
                    >
                      Add
                    </button>
                    <button
                      @click="removeSegment"
                      class="tw-px-2 tw-py-1 tw-text-[10px] tw-font-medium tw-bg-red-600 tw-text-white tw-rounded hover:tw-bg-red-700 disabled:tw-opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'tw-hidden': segmentLocked }"
                    >
                      Remove
                    </button>

                    <button @click="playWord" class="tw-px-2 tw-py-1 tw-text-[10px] tw-font-medium tw-bg-gray-600 tw-text-white tw-rounded hover:tw-bg-gray-700">
                      {{ playingWord == index + 1 ? 'Playing' : 'Play' }}
                    </button>

                    <button
                      @click="loopWord"
                      class="tw-px-2 tw-py-1 tw-text-[10px] tw-font-medium tw-bg-gray-600 tw-text-white tw-rounded hover:tw-bg-gray-700"
                    >
                      {{ loopingWord == index + 1 ? 'Looping' : 'Loop' }}
                    </button>

                    <button
                      @click="trackTime"
                      class="tw-px-2 tw-py-1 tw-text-[10px] tw-font-medium tw-bg-yellow-500 tw-text-white tw-rounded hover:tw-bg-yellow-600 disabled:tw-opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'tw-hidden': segmentLocked }"
                    >
                      Track
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

export default {
  name: 'Verse',
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
    changeAyah(event) {
      this.$store.commit('CHANGE_AYAH', { to: event.target.value });
    },
    loopWord(event) {
      this.$store.commit('TOGGLE_LOOP_WORD', {
        word: event.target.parentNode.parentNode.dataset.word,
      });

      if (player.paused) playAyah();
    },
    playWord(event) {
      player.pause();
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
      'rawSegments'
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

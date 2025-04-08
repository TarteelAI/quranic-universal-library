<template>
  <div class="row">
    <div class="col-12" v-if="segmentsLoaded">
      <div class="h3">
        Current Ayah {{ currentVerseKey }}

        <select @change="changeAyah">
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

      <div class="qpc-hafs d-flex flex-wrap words">
        <span
          :id="index + 1"
          :class="[this.getWordCssClass(index)]"
          v-for="(text, index) in wordsText"
          :key="index"
          title="Repeat word"
          @click="showWordPopover"
        >
          {{ text }}
        </span>
      </div>

      <div v-if="shouldShowSegment">
        <h4 class="d-flex justify-content-between mt-4">
          <div>Segments</div>

          <div>
            <button
                @click="showRawSegment"
                :disabled="segmentLocked"
                class="btn btn-sm btn-info me-2"
            >
              Show raw segments
            </button>

            <button
                @click="toggleSegmentTiming"
                :disabled="segmentLocked"
                class="btn btn-sm btn-danger me-2"
                :class="{ 'd-none': segmentLocked }"
            >
              {{this.verseSegment.segments[0].length > 1 ? 'Clear Segment' : 'Reload Segments'}}
            </button>

            <button
                @click="saveAyahSegment"
                :disabled="segmentLocked"
                class="btn btn-sm btn-success"
                :class="{ 'd-none': segmentLocked }"
            >
              Save Segments
            </button>
          </div>
        </h4>

        <div v-if="rawSegmentVisible" class="mt-3">
          <textarea
              class="form-control"
              @input="updateRawSegments"
          ></textarea>
        </div>
        <div class="small" v-if="rawSegments[currentVerseNumber]">
          {{ JSON.stringify(rawSegments[currentVerseNumber]) }}
        </div>

        <div class="table-wrapper" id="tableWrapper">
          <table class="table table-hover mt-4">
            <thead>
            <tr>
              <td>Word</td>
              <td>Text</td>
              <td>Start</td>
              <td>Ends</td>
              <td>Actions</td>
            </tr>
            </thead>
            <tbody>
              <tr
                :id="[`word-${segment[0]}-${index}`]"
                :class="[index + 1 == currentWord ? 'active word' : 'word']"
                v-for="(segment, index) in verseSegment.segments"
                :key="index"
                :data-index="index"
                :data-word="segment[0]"
              >
                <td>
                  <input
                    type="number"
                    min="1"
                    :value="segment[0]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentNumber"
                  />
                  <small class="form-text flex">
                    <span>{{ segment[0] }} </span>
                  </small>
                </td>

                <td>{{ segmentText(segment) }}</td>
                <td style="width: 200px">
                  <input
                    type="number"
                    min="0"
                    :id="[`start-${segment[0]}-${index}`]"
                    :value="segment[1]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentStart"
                  />
                  <small class="form-text d-flex justify-content-between">
                    <span>
                      {{ segmentOriginalStart(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment start">
                      {{ rawSegmentStart(index) }}
                    </span>
                  </small>
                </td>

                <td style="width: 200px">
                  <input
                    type="number"
                    min="0"
                    :value="segment[2]"
                    :id="[`end-${segment[0]}-${index}`]"
                    :data-index="index"
                    :disabled="segmentLocked"
                    @change="updateSegmentEnd"
                  />
                  <small class="form-text d-flex justify-content-between">
                    <span>
                      {{ segmentOriginalEnd(index) }}
                    </span>

                    <span data-controller="tooltip" title="Suggested segment end">
                      {{rawSegmentEnd(index)}}
                    </span>
                  </small>
                </td>

                <td :data-word="segment[0]" :data-index="index">
                  <div
                      class="d-flex gap-1"
                      :data-word="segment[0]" :data-index="index"
                  >
                    <button
                      @click="insertSegment"
                      class="btn btn-sm btn-info"
                      :disabled="segmentLocked"
                      :class="{ 'd-none': segmentLocked }"
                    >
                      Add
                    </button>
                    <button
                      @click="removeSegment"
                      class="me-2 btn btn-sm btn-danger"
                      :disabled="segmentLocked"
                      :class="{ 'd-none': segmentLocked }"
                    >
                      Remove
                    </button>

                    <button @click="playWord" class="btn btn-sm btn-secondary">
                      {{ playingWord == index + 1 ? 'Playing' : 'Play' }}
                    </button>

                    <button
                      @click="loopWord"
                      class="me-2 btn btn-sm btn-secondary"
                    >
                      {{ loopingWord == index + 1 ? 'Looping' : 'Loop' }}
                    </button>

                    <button
                      @click="trackTime"
                      class="btn btn-sm btn-warning"
                      :disabled="segmentLocked"
                      :class="{ 'd-none': segmentLocked }"
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

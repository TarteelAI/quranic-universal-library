<template>
  <div class="flex flex-wrap">
    <div class="w-full" v-if="segmentsLoaded">
      <div class="qpc-hafs flex flex-wrap gap-2 p-4 bg-gray-50 rounded-lg mb-6 sticky top-0 z-50 shadow-sm words">
        <span
          :id="index + 1"
          :class="[this.getWordCssClass(index)]"
          :style="compareWordColors[index + 1] ? { backgroundColor: compareWordColors[index + 1] } : null"
          v-for="(text, index) in wordsText"
          :key="index"
          title="Repeat word"
          @click="showWordPopover"
          class="px-2 py-1 border border-dotted border-green-600 rounded cursor-pointer transition-colors inline-flex flex-col items-center"
        >
          {{ text }}
          <span v-if="compareWordMarkers[index + 1]" class="flex gap-0.5 mt-0.5 pointer-events-none">
            <span
              v-for="(color, i) in compareWordMarkers[index + 1]"
              :key="i"
              class="inline-block w-4 h-1.5 rounded-sm"
              :style="{ backgroundColor: color }"
            ></span>
          </span>
        </span>
      </div>

      <div
          v-if="showIssues"
          class="fixed inset-0 z-[100] flex items-start justify-center bg-black/40 p-4 overflow-y-auto"
          @click.self="showIssues = false"
      >
        <div class="bg-white rounded-lg shadow-xl w-full max-w-lg mt-16">
          <div class="flex items-center justify-between px-4 py-3 border-b">
            <h3 class="text-base font-semibold">
              Segment issues ({{ activeIssues.length }})
            </h3>
            <button @click="showIssues = false" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">×</button>
          </div>

          <div v-if="issueGroups.length > 1" class="flex flex-wrap gap-1 px-4 py-2 border-b bg-gray-50">
            <button
                v-for="group in issueGroups"
                :key="group.id"
                @click="activeIssueTab = group.id"
                class="flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-full border"
                :class="activeIssueTab === group.id ? 'bg-white border-gray-400 text-gray-800' : 'bg-transparent border-transparent text-gray-500 hover:text-gray-700'"
            >
              <span class="inline-block w-2.5 h-2.5 rounded-full" :style="{ backgroundColor: group.color }"></span>
              {{ group.name }}
              <span
                  class="px-1.5 py-0.5 text-[10px] font-semibold rounded-full"
                  :class="group.issues.length ? 'bg-red-100 text-red-700' : 'bg-gray-200 text-gray-500'"
              >{{ group.issues.length }}</span>
            </button>
          </div>

          <div class="max-h-[60vh] overflow-y-auto divide-y divide-gray-100">
            <p v-if="!activeIssues.length" class="px-4 py-8 text-sm text-gray-500 text-center">
              No issues found 🎉
            </p>
            <button
                v-for="issue in activeIssues"
                :key="issue.key"
                @click="goToIssue(issue.verse)"
                class="w-full flex items-center justify-between gap-3 px-4 py-3 text-left hover:bg-gray-50"
            >
              <span class="flex items-center gap-2 text-sm text-gray-700">
                <span
                    class="px-1.5 py-0.5 text-[10px] font-semibold rounded-full uppercase"
                    :class="issue.severity === 'major' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-800'"
                >
                  {{ issue.severity }}
                </span>
                {{ issue.message }}
              </span>
              <span class="text-xs font-medium text-blue-600 whitespace-nowrap">Ayah {{ issue.verse }} →</span>
            </button>
          </div>
        </div>
      </div>

      <div
          v-if="showCompare"
          class="fixed inset-0 z-[100] flex items-start justify-center bg-black/40 p-4 overflow-y-auto"
          @click.self="showCompare = false"
      >
        <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl mt-12">
          <div class="flex items-center justify-between px-4 py-3 border-b">
            <h3 class="text-base font-semibold">Compare segment sources</h3>
            <button @click="showCompare = false" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">×</button>
          </div>

          <div class="px-4 py-3 max-h-[65vh] overflow-y-auto space-y-4">
            <p class="text-xs text-gray-500">
              Paste segment timing from another source. On playback each source highlights the word it
              thinks is active, in its own color, so you can see whose timing matches best.
            </p>

            <p v-if="!compareSources.length" class="text-sm text-gray-500 text-center py-4">
              No sources yet. Add one to start comparing.
            </p>

            <div v-for="source in compareSources" :key="source.id" class="border border-gray-200 rounded-md p-3">
              <div class="flex items-center justify-between mb-2">
                <span class="flex items-center gap-2 text-sm font-medium text-gray-700">
                  <span class="inline-block w-3 h-3 rounded-full" :style="{ backgroundColor: source.color }"></span>
                  {{ source.name }}
                  <span v-if="source.error" class="text-xs text-red-600 font-normal">invalid JSON</span>
                </span>
                <div class="flex items-center gap-2">
                  <button
                      @click="playCompareSource(source.id)"
                      :style="{ backgroundColor: source.color }"
                      :title="`Play this ayah using ${source.name} timing`"
                      class="inline-flex items-center justify-center px-2 py-0.5 rounded text-white text-[10px] font-medium hover:opacity-80"
                  >▶ Play</button>
                  <button @click="removeCompareSource(source.id)" class="text-xs font-medium text-red-600 hover:text-red-700">
                    Remove
                  </button>
                </div>
              </div>
              <textarea
                  v-if="!source.recitationId"
                  rows="4"
                  :value="source.text"
                  @input="updateCompareSource(source.id, $event.target.value)"
                  placeholder='{ "1": [[1, 0, 500], [2, 500, 900]] }'
                  class="w-full px-3 py-2 text-xs font-mono border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              ></textarea>
              <p v-if="!source.recitationId" class="text-[10px] text-gray-400 mt-1">
                Format: <code>{ "verse": [[word, start, end], ...] }</code> — times in ms, e.g.
                <code>{ "1": [[1, 0, 500], [2, 500, 900]] }</code>
              </p>
              <p v-else class="text-[10px] text-gray-400 mt-1">
                Loaded from recitation #{{ source.recitationId }}.
              </p>
            </div>
          </div>

          <div class="flex items-center justify-between px-4 py-3 border-t">
            <div class="flex items-center gap-2">
              <button @click="addCompareSource" class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded hover:bg-blue-700">
                + Add source
              </button>
              <select
                  v-if="compareRecitations.length"
                  @change="addCompareRecitation"
                  class="px-2 py-1 text-xs border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">+ Add recitation…</option>
                <option v-for="r in compareRecitations" :key="r.id" :value="r.id">{{ r.name }}</option>
              </select>
            </div>
            <button @click="showCompare = false" class="px-3 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300">
              Done
            </button>
          </div>
        </div>
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

            <span
                v-if="currentAyahIssue"
                class="flex items-center gap-1 px-2 py-0.5 text-[11px] font-medium rounded-full"
                :class="currentAyahIssue.severity === 'major' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-800'"
                data-controller="tooltip"
                :title="currentAyahIssue.message"
            >
              ⚠ {{ currentAyahIssue.severity === 'major' ? 'Has major issue' : 'Has minor issue' }}
            </span>
          </div>

          <div class="flex items-center gap-2">
            <label
                class="flex items-center gap-1 text-xs text-gray-700 mr-1"
                data-controller="tooltip"
                title="Automatically save the word segments as soon as you make a change, and when moving between ayahs."
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
                @click="undo"
                :disabled="!canUndo || segmentLocked"
                data-controller="tooltip"
                title="Undo last change (Ctrl/Cmd+Z)"
                class="px-3 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
            >
              Undo
            </button>

            <button
                @click="redo"
                :disabled="!canRedo || segmentLocked"
                data-controller="tooltip"
                title="Redo (Ctrl/Cmd+Shift+Z)"
                class="px-3 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
            >
              Redo
            </button>

            <button
                @click="openIssues"
                data-controller="tooltip"
                title="Find segment issues across the whole surah"
                class="px-3 py-1 text-xs font-medium bg-amber-500 text-white rounded hover:bg-amber-600"
            >
              Find issues
            </button>

            <button
                @click="showCompare = true"
                data-controller="tooltip"
                title="Compare timing against pasted sources by color on playback"
                class="px-3 py-1 text-xs font-medium bg-cyan-600 text-white rounded hover:bg-cyan-700"
            >
              Compare<span v-if="compareSources.length"> ({{ compareSources.length }})</span>
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
            <span class="inline-block w-4 h-4 rounded-sm bg-red-100 border border-red-300"></span>
            Major issue (first/last word)
          </span>
          <span class="flex items-center gap-1">
            <span class="inline-block w-4 h-4 rounded-sm bg-yellow-100 border border-yellow-300"></span>
            Minor issue
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

        <div v-if="compareSources.length" class="flex flex-wrap items-center gap-3 mb-3 text-xs text-gray-500">
          <span>Compare:</span>
          <span v-for="source in compareSources" :key="source.id" class="flex items-center gap-1">
            <span class="inline-block w-3 h-3 rounded-full" :style="{ backgroundColor: source.color }"></span>
            {{ source.name }}
          </span>
        </div>

        <div class="overflow-x-auto overflow-y-auto max-h-[60vh] border border-gray-200 rounded-lg" id="tableWrapper">
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
                      data-controller="tooltip"
                      :title="`Decrease start by ${timeStep}ms`"
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
                      data-controller="tooltip"
                      :title="`Increase start by ${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      +
                    </button>
                  </div>
                  <small class="block text-[10px] text-gray-400 mt-0.5">
                    {{ segmentOriginalStart(index) }}
                  </small>
                </td>

                <td class="px-4 py-2 w-48">
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      @click="adjustSegmentTime(index, 2, -timeStep)"
                      :disabled="segmentLocked"
                      data-controller="tooltip"
                      :title="`Decrease end by ${timeStep}ms`"
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
                      data-controller="tooltip"
                      :title="`Increase end by ${timeStep}ms`"
                      class="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50"
                    >
                      +
                    </button>
                  </div>
                  <small class="block text-[10px] text-gray-400 mt-0.5">
                    {{ segmentOriginalEnd(index) }}
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
                    class="flex flex-wrap items-center gap-1"
                    :data-word="segment[0]" :data-index="index"
                >
                    <button
                      @click="trackTime"
                      class="px-3 py-1 text-[10px] font-semibold bg-amber-500 text-white rounded ring-1 ring-amber-300 hover:bg-amber-600 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                      title="Track the current playback time for this word"
                      data-controller="tooltip"
                    >
                      Track
                    </button>

                    <span class="self-stretch w-px bg-gray-200 mx-1" :class="{ 'hidden': segmentLocked }"></span>

                    <button @click="playWord" class="px-2 py-1 text-[10px] font-medium bg-slate-600 text-white rounded hover:bg-slate-700">
                      {{ playingWord == index + 1 ? 'Playing' : 'Play' }}
                    </button>

                    <button
                      v-for="source in compareSources"
                      :key="source.id"
                      @click="playCompareWord(source.id, segment[0])"
                      :style="{ backgroundColor: source.color }"
                      :title="`Play word ${segment[0]} using ${source.name} timing`"
                      class="inline-flex items-center justify-center w-6 h-6 rounded-full text-white text-[10px] leading-none hover:opacity-80"
                    >▶</button>

                    <span class="self-stretch w-px bg-gray-200 mx-1" :class="{ 'hidden': segmentLocked }"></span>

                    <button
                      @click="insertSegment"
                      class="px-2 py-1 text-[10px] font-medium bg-emerald-600 text-white rounded hover:bg-emerald-700 disabled:opacity-50"
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

                    <span
                      v-if="canSplit(index) || canFill(index)"
                      class="self-stretch w-px bg-gray-200 mx-1"
                      :class="{ 'hidden': segmentLocked }"
                    ></span>

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

                    <button
                      v-if="canFill(index)"
                      @click="fillSegment(index)"
                      class="px-2 py-1 text-[10px] font-medium bg-teal-600 text-white rounded hover:bg-teal-700 disabled:opacity-50"
                      :disabled="segmentLocked"
                      :class="{ 'hidden': segmentLocked }"
                      title="Fill this word's timing from the gap between the previous and next word"
                      data-controller="tooltip"
                    >
                      Fill
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
      showIssues: false,
      issueGroups: [],
      activeIssueTab: 'current',
      showCompare: false,
    };
  },
  created() {
    window.store = this.$store;

    this.unwatch = this.$store.watch(
      (state) => state.currentWord,
      (newValue, _) => {
        this.scrollToCurrentWord(newValue);
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
    addCompareSource() {
      this.$store.commit('ADD_COMPARE_SOURCE');
    },
    removeCompareSource(id) {
      this.$store.commit('REMOVE_COMPARE_SOURCE', { id });
    },
    updateCompareSource(id, text) {
      this.$store.commit('UPDATE_COMPARE_SOURCE', { id, text });
    },
    addCompareRecitation(event) {
      const recitationId = event.target.value;
      if (!recitationId) return;
      this.$store.dispatch('ADD_COMPARE_RECITATION', { recitationId });
      event.target.value = '';
    },
    playCompareWord(id, word) {
      this.$store.commit('PLAY_COMPARE_WORD', { id, word });
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
    playerDurationMs() {
      return (typeof player !== 'undefined' && player && isFinite(player.duration) && player.duration > 0)
        ? player.duration * 1000
        : null;
    },
    lastWordNumber() {
      return Math.max(0, (this.wordsText ? this.wordsText.length : 0) - 1);
    },
    classifyWordIssue(segment, wordNumber, lastWordNumber, audioDuration) {
      const present = (value) => value !== undefined && value !== null && value !== '';
      const hasStart = present(segment[1]);
      const hasEnd = present(segment[2]);

      let problem;
      if (!hasStart || !hasEnd) {
        problem = true;
      } else if (Number(segment[2]) <= Number(segment[1])) {
        problem = true;
      } else if (audioDuration && Number(segment[2]) > audioDuration) {
        problem = true;
      }

      if (!problem) return null;

      const isEdge = wordNumber === 1 || wordNumber === lastWordNumber;
      return isEdge ? 'major' : 'minor';
    },
    wordIssueMessage(segment, audioDuration) {
      const present = (value) => value !== undefined && value !== null && value !== '';
      if (!present(segment[1]) || !present(segment[2])) return `Word ${segment[0]} has no timing`;
      if (Number(segment[2]) <= Number(segment[1])) return `Word ${segment[0]} end time is before or equal to its start`;
      if (audioDuration && Number(segment[2]) > audioDuration) return `Word ${segment[0]} goes past the audio duration`;
      return `Word ${segment[0]} has a timing issue`;
    },
    wordSeverity(segment) {
      return this.classifyWordIssue(segment, Number(segment[0]), this.lastWordNumber(), this.playerDurationMs());
    },
    overlapsPreviousWord(segments, index) {
      if (!segments || index <= 0) return false;

      const present = (value) => value !== undefined && value !== null && value !== '';
      const current = segments[index];
      if (!current || !present(current[1])) return false;

      for (let i = index - 1; i >= 0; i--) {
        if (present(segments[i][2])) {
          return Number(current[1]) < Number(segments[i][2]);
        }
      }

      return false;
    },
    segmentRowClass(segment, index) {
      const current = index + 1 == this.currentWord;
      let severity = this.wordSeverity(segment);

      if (!severity && this.overlapsPreviousWord(this.verseSegment.segments, index)) {
        severity = 'minor';
      }

      if (severity === 'major') return ['bg-red-100'];
      if (severity === 'minor') return ['bg-yellow-100'];
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
    canFill(index) {
      const segment = this.verseSegment.segments[index];
      if (!segment) return false;

      const present = (value) => value !== undefined && value !== null && value !== '';
      return !present(segment[1]) && !present(segment[2]);
    },
    fillSegment(index) {
      this.$store.commit('FILL_SEGMENT_TIME', { index });

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
    undo() {
      this.$store.commit('UNDO_SEGMENTS');
    },
    redo() {
      this.$store.commit('REDO_SEGMENTS');
    },
    openIssues() {
      const groups = [
        { id: 'current', name: 'Current', color: '#198754', issues: this.findSegmentIssues((verse) => this.mainVerseData(verse)) },
      ];

      for (const source of this.compareSources) {
        groups.push({
          id: source.id,
          name: source.name,
          color: source.color,
          issues: this.findSegmentIssues((verse) => this.sourceVerseData(source, verse)),
        });
      }

      this.issueGroups = groups;
      this.activeIssueTab = 'current';
      this.showIssues = true;
    },
    goToIssue(verse) {
      this.$store.commit('CHANGE_AYAH', { to: verse });
      this.showIssues = false;
    },
    mainVerseData(verse) {
      return this.segments[`${this.chapter}:${verse}`] || null;
    },
    sourceVerseData(source, verse) {
      const compareKey = this.audioType == 'ayah' ? `${this.chapter}:${verse}` : verse;
      const segments = source.segments && source.segments[compareKey];
      if (!segments || !segments.length) return null;

      const present = (value) => value !== undefined && value !== null && value !== '';
      const main = this.segments[`${this.chapter}:${verse}`];

      return {
        timestamp_from: present(segments[0][1]) ? Number(segments[0][1]) : undefined,
        timestamp_to: present(segments[segments.length - 1][2]) ? Number(segments[segments.length - 1][2]) : undefined,
        words: (main && main.words) || [],
        segments,
      };
    },
    findSegmentIssues(verseDataFor) {
      const issues = [];
      // Flag a file when the audio continues this many ms past the last ayah.
      const TRAILING_GAP_THRESHOLD_MS = 1000;
      const audioDuration = (typeof player !== 'undefined' && player && isFinite(player.duration) && player.duration > 0)
        ? player.duration * 1000
        : null;

      const present = (value) => value !== undefined && value !== null && value !== '';

      for (let verse = 1; verse <= this.versesCount; verse++) {
        const data = verseDataFor(verse);
        if (!data) continue;

        const nextData = verseDataFor(verse + 1);
        const nextAyahStart = (nextData && present(nextData.timestamp_from)) ? Number(nextData.timestamp_from) : null;

        const issue = this.detectAyahIssue(data, audioDuration, nextAyahStart);
        if (issue) issues.push({ verse, key: `${verse}-${issues.length}`, severity: issue.severity, message: issue.message });

        // Trailing gap: audio runs well past the last ayah's end (unsegmented tail).
        if (verse === this.versesCount && audioDuration && present(data.timestamp_to)) {
          const gap = audioDuration - Number(data.timestamp_to);
          if (gap > TRAILING_GAP_THRESHOLD_MS) {
            issues.push({
              verse,
              key: `${verse}-${issues.length}`,
              severity: 'major',
              message: `Audio continues ${Math.round(gap / 1000)}s past the last ayah ends (unsegmented tail)`
            });
          }
        }
      }

      // Surface major issues first so reviewers triage the important ayahs.
      issues.sort((a, b) => (a.severity === 'major' ? 0 : 1) - (b.severity === 'major' ? 0 : 1));

      return issues;
    },
    detectAyahIssue(data, audioDuration, nextAyahStart) {
      const present = (value) => value !== undefined && value !== null && value !== '';
      // Reciters pause between ayahs, but a silence longer than this usually
      // means the ayah boundary timestamps are wrong.
      const AYAH_GAP_THRESHOLD_MS = 2000;

      if (!present(data.timestamp_from) || !present(data.timestamp_to) ||
          Number(data.timestamp_from) >= Number(data.timestamp_to)) {
        return { severity: 'major', message: 'Ayah start/end time is missing or invalid' };
      }

      if (nextAyahStart !== null && Number(data.timestamp_to) > nextAyahStart) {
        return { severity: 'major', message: 'Overlaps the next ayah' };
      }

      const segments = data.segments || [];
      const firstWordSegment = segments.find((seg) => Number(seg[0]) === 1);
      if (firstWordSegment && present(firstWordSegment[1]) &&
          Number(data.timestamp_from) > Number(firstWordSegment[1])) {
        return { severity: 'major', message: 'Ayah starts after its first word starts' };
      }

      const words = data.words || [];
      const lastWordNumber = Math.max(0, words.length - 1);
      const covered = new Set();
      let minor = null;
      let previousEnd = null;

      if (nextAyahStart !== null) {
        const gap = nextAyahStart - Number(data.timestamp_to);
        if (gap > AYAH_GAP_THRESHOLD_MS) {
          minor = { severity: 'minor', message: `Gap of ${(gap / 1000).toFixed(1)}s before the next ayah (max allowed is 2s)` };
        }
      }

      for (let i = 0; i < segments.length; i++) {
        const seg = segments[i];
        const wordNumber = Number(seg[0]);
        covered.add(wordNumber);

        const severity = this.classifyWordIssue(seg, wordNumber, lastWordNumber, audioDuration);
        if (severity === 'major') {
          return { severity: 'major', message: this.wordIssueMessage(seg, audioDuration) };
        }
        if (severity === 'minor' && !minor) {
          minor = { severity: 'minor', message: this.wordIssueMessage(seg, audioDuration) };
        }

        if (!minor && previousEnd !== null && present(seg[1]) && Number(seg[1]) < previousEnd) {
          minor = { severity: 'minor', message: `Word ${seg[0]} starts before the previous word ends` };
        }
        if (present(seg[2])) previousEnd = Number(seg[2]);
      }

      for (let word = 1; word <= lastWordNumber; word++) {
        if (covered.has(word)) continue;

        if (word === 1 || word === lastWordNumber) {
          return { severity: 'major', message: `Missing segment for the ${word === 1 ? 'first' : 'last'} word` };
        }
        if (!minor) minor = { severity: 'minor', message: 'Missing segments for some words' };
      }

      return minor;
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
    playCompareSource(id) {
      this.$store.commit('PLAY_COMPARE_SOURCE', { id });
    },
    scrollToCurrentWord(word) {
      if (!this.autoScroll) return;

      this.$nextTick(() => {
        const wrapper = document.getElementById('tableWrapper');
        if (!wrapper) return;

        const row = wrapper.querySelector(`tbody tr[data-index="${Number(word) - 1}"]`);
        if (!row) return;

        // Scroll the table container only — never the page — so the reviewer's
        // place on the rest of the page is left untouched. Account for the
        // sticky header so the active row isn't hidden behind it.
        const wrapperRect = wrapper.getBoundingClientRect();
        const rowRect = row.getBoundingClientRect();
        const headerHeight = wrapper.querySelector('thead')?.getBoundingClientRect().height || 0;

        const above = rowRect.top < wrapperRect.top + headerHeight;
        const below = rowRect.bottom > wrapperRect.bottom;
        if (!above && !below) return;

        const delta = above
          ? rowRect.top - wrapperRect.top - headerHeight
          : rowRect.bottom - wrapperRect.bottom;

        wrapper.scrollBy({ top: delta, behavior: 'smooth' });
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
      'compareSources',
      'compareActiveWords',
      'compareRecitations',
      'segmentsUnsaved',
      'segmentsSaved',
      'saving',
      'autoSaveSegments',
      'loadedSegments',
      'undoStack',
      'redoStack',
      'segments',
      'chapter',
      'autoScroll'
    ]),
    activeIssueGroup() {
      return this.issueGroups.find((group) => group.id === this.activeIssueTab) || this.issueGroups[0] || null;
    },
    activeIssues() {
      return this.activeIssueGroup ? this.activeIssueGroup.issues : [];
    },
    compareWordColors() {
      const colors = {};

      for (const source of this.compareSources) {
        const word = this.compareActiveWords[source.id];
        if (word && word !== this.currentWord && colors[word] === undefined) {
          colors[word] = source.color;
        }
      }

      return colors;
    },
    compareWordMarkers() {
      const markers = {};

      for (const source of this.compareSources) {
        const word = this.compareActiveWords[source.id];
        if (!word) continue;

        (markers[word] || (markers[word] = [])).push(source.color);
      }

      return markers;
    },
    canUndo() {
      return this.undoStack.length > 1;
    },
    canRedo() {
      return this.redoStack.length > 0;
    },
    segmentsLoaded() {
      return !!this.verseSegment;
    },
    shouldShowSegment() {
      return this.showSegments && this.segmentsLoaded;
    },
    currentAyahIssue() {
      const data = this.verseSegment;
      if (!data || !data.segments) return null;

      const present = (value) => value !== undefined && value !== null && value !== '';
      const nextData = this.segments[`${this.chapter}:${Number(this.currentVerseNumber) + 1}`];
      const nextAyahStart = (nextData && present(nextData.timestamp_from)) ? Number(nextData.timestamp_from) : null;

      return this.detectAyahIssue(data, this.playerDurationMs(), nextAyahStart);
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

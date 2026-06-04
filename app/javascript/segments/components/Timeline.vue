<template>
  <div v-if="showTimeline && segmentsLoaded" class="border border-gray-200 rounded-lg bg-white">
    <div class="flex items-center justify-between px-3 py-2 border-b border-gray-100">
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium text-gray-700">Timeline</span>
        <div class="flex items-center gap-1">
          <button
              @click="zoomOut"
              :disabled="!canZoomOut"
              class="w-6 h-6 flex items-center justify-center text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-40"
              title="Zoom out"
              data-controller="tooltip"
          >−</button>
          <button
              @click="zoomReset"
              class="px-2 h-6 flex items-center justify-center text-[11px] font-medium bg-gray-100 text-gray-600 rounded hover:bg-gray-200"
              title="Reset zoom"
              data-controller="tooltip"
          >{{ Math.round(pxPerMs * 1000) }} px/s</button>
          <button
              @click="zoomIn"
              :disabled="!canZoomIn"
              class="w-6 h-6 flex items-center justify-center text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-40"
              title="Zoom in"
              data-controller="tooltip"
          >+</button>
        </div>
      </div>
      <div class="flex items-center gap-3 text-[10px] text-gray-400">
        <span>click to seek</span>
        <button @click="scrollToCurrentAyah" class="text-blue-600 hover:text-blue-700 font-medium">
          Jump to current ayah
        </button>
      </div>
    </div>

    <div ref="scroller" class="overflow-x-auto overflow-y-hidden">
      <div
          ref="track"
          class="relative"
          dir="rtl"
          :style="{ width: trackWidth + 'px', height: trackHeight + 'px' }"
          @click="seek"
      >
        <!-- ayah bands -->
        <div
            v-for="band in ayahBands"
            :key="'band-' + band.verse"
            class="absolute inset-y-0 border-r"
            :class="band.overlap ? 'bg-red-50 border-red-400' : (band.isCurrent ? 'bg-blue-50 border-blue-300' : (band.verse % 2 ? 'bg-gray-50/60 border-gray-100' : 'bg-white border-gray-100'))"
            :style="{ right: band.left + 'px', width: band.width + 'px' }"
        >
          <span
              class="absolute top-0 right-1 text-[8px] font-medium"
              :class="band.isCurrent ? 'text-blue-600' : 'text-gray-400'"
          >
            {{ band.verse }}
          </span>
        </div>

        <!-- word blocks -->
        <div
            v-for="block in wordBlocks"
            :key="block.key"
            class="absolute flex items-center justify-center overflow-hidden rounded-sm border text-[9px] leading-none qpc-hafs shadow-sm"
            :class="block.invalid
              ? 'bg-red-100 border-red-400 text-red-700'
              : (block.overlap
                ? 'bg-orange-100 border-orange-500 text-orange-800'
                : (block.isCurrent ? 'bg-blue-200 border-blue-400 text-blue-900' : 'bg-blue-100 border-blue-200 text-blue-800'))"
            :style="{ right: block.left + 'px', width: block.width + 'px', top: mainTop + 'px', height: mainH + 'px' }"
            :title="block.title"
        >
          <span v-if="block.width > 22" class="px-0.5 truncate">{{ block.label }}</span>
        </div>

        <!-- compare lanes -->
        <template v-for="(source, i) in compareSources">
          <div
              v-for="block in sourceBlocks(source)"
              :key="block.key"
              class="absolute rounded-sm opacity-80"
              :style="{
                right: block.left + 'px',
                width: block.width + 'px',
                top: laneTop(i) + 'px',
                height: laneH + 'px',
                backgroundColor: source.color,
              }"
              :title="block.title"
          ></div>
        </template>

        <!-- playhead -->
        <div class="absolute inset-y-0 w-px bg-gray-900 pointer-events-none" :style="{ right: playheadLeft + 'px' }">
          <span class="absolute -top-px -right-1 w-2 h-2 rotate-45 bg-gray-900"></span>
        </div>
      </div>
    </div>

    <div v-if="compareSources.length" class="flex flex-wrap gap-3 px-3 py-2 border-t border-gray-100 text-[10px] text-gray-500">
      <span class="flex items-center gap-1">
        <span class="inline-block w-3 h-2 rounded-sm bg-blue-100 border border-blue-300"></span>
        Current segments
      </span>
      <span v-for="source in compareSources" :key="source.id" class="flex items-center gap-1">
        <span class="inline-block w-3 h-2 rounded-sm" :style="{ backgroundColor: source.color }"></span>
        {{ source.name }}
      </span>
    </div>
  </div>
</template>

<script>
import { mapState } from 'vuex';

export default {
  name: 'Timeline',
  data() {
    return {
      pxPerMs: 0.1,
      minPxPerMs: 0.02,
      maxPxPerMs: 0.6,
      mainTop: 18,
      mainH: 30,
      laneH: 14,
      laneGap: 2,
    };
  },
  watch: {
    currentVerseNumber() {
      this.$nextTick(() => this.scrollToCurrentAyah());
    },
    showTimeline(visible) {
      if (visible) this.$nextTick(() => this.scrollToCurrentAyah());
    },
  },
  mounted() {
    this.$nextTick(() => this.scrollToCurrentAyah());
  },
  computed: {
    ...mapState([
      'showTimeline',
      'verseSegment',
      'wordsText',
      'compareSources',
      'currentTimestamp',
      'currentVerseNumber',
      'versesCount',
      'audioType',
      'segments',
      'chapter',
    ]),
    segmentsLoaded() {
      return !!this.verseSegment;
    },
    canZoomIn() {
      return this.pxPerMs < this.maxPxPerMs;
    },
    canZoomOut() {
      return this.pxPerMs > this.minPxPerMs;
    },
    rangeEndMs() {
      let end = (typeof player !== 'undefined' && player && isFinite(player.duration) && player.duration > 0)
        ? player.duration * 1000
        : 0;

      for (let verse = 1; verse <= this.versesCount; verse++) {
        const data = this.segments[`${this.chapter}:${verse}`];
        if (data && this.present(data.timestamp_to)) end = Math.max(end, Number(data.timestamp_to));
      }

      return Math.max(1, end);
    },
    trackWidth() {
      return this.rangeEndMs * this.pxPerMs;
    },
    trackHeight() {
      return this.laneTop(this.compareSources.length) + 4;
    },
    ayahBands() {
      const bands = [];

      for (let verse = 1; verse <= this.versesCount; verse++) {
        const data = this.segments[`${this.chapter}:${verse}`];
        if (!data || !this.present(data.timestamp_from) || !this.present(data.timestamp_to)) continue;

        const from = Number(data.timestamp_from);
        const to = Number(data.timestamp_to);

        const nextData = this.segments[`${this.chapter}:${verse + 1}`];
        const nextFrom = (nextData && this.present(nextData.timestamp_from)) ? Number(nextData.timestamp_from) : null;

        bands.push({
          verse,
          left: from * this.pxPerMs,
          width: Math.max(1, (to - from) * this.pxPerMs),
          isCurrent: verse == this.currentVerseNumber,
          overlap: nextFrom !== null && to > nextFrom,
        });
      }

      return bands;
    },
    wordBlocks() {
      const blocks = [];

      for (let verse = 1; verse <= this.versesCount; verse++) {
        const data = this.segments[`${this.chapter}:${verse}`];
        if (!data) continue;

        const words = data.words || [];
        const isCurrent = verse == this.currentVerseNumber;
        let previousEnd = null;
        let previousBlock = null;

        (data.segments || []).forEach((segment, index) => {
          if (!this.present(segment[1]) || !this.present(segment[2])) return;

          const start = Number(segment[1]);
          const end = Number(segment[2]);

          const block = {
            key: `w-${verse}-${index}`,
            left: start * this.pxPerMs,
            width: Math.max(2, (end - start) * this.pxPerMs),
            invalid: end <= start,
            overlap: false,
            isCurrent,
            label: words[segment[0] - 1] || segment[0],
            title: `${verse}:${segment[0]} — ${start}–${end} ms`,
          };

          if (previousEnd !== null && start < previousEnd) {
            block.overlap = true;
            if (previousBlock) previousBlock.overlap = true;
          }

          blocks.push(block);
          previousEnd = end;
          previousBlock = block;
        });
      }

      return blocks;
    },
    playheadLeft() {
      return Math.max(0, this.currentTimestamp * this.pxPerMs);
    },
  },
  methods: {
    present(value) {
      return value !== undefined && value !== null && value !== '';
    },
    laneTop(index) {
      return this.mainTop + this.mainH + 4 + index * (this.laneH + this.laneGap);
    },
    zoomIn() {
      this.pxPerMs = Math.min(this.maxPxPerMs, Number((this.pxPerMs * 1.4).toFixed(4)));
      this.$nextTick(() => this.scrollToCurrentAyah());
    },
    zoomOut() {
      this.pxPerMs = Math.max(this.minPxPerMs, Number((this.pxPerMs / 1.4).toFixed(4)));
      this.$nextTick(() => this.scrollToCurrentAyah());
    },
    zoomReset() {
      this.pxPerMs = 0.1;
      this.$nextTick(() => this.scrollToCurrentAyah());
    },
    sourceBlocks(source) {
      const blocks = [];

      for (let verse = 1; verse <= this.versesCount; verse++) {
        const key = this.audioType == 'ayah' ? `${this.chapter}:${verse}` : verse;
        const segments = (source.segments && source.segments[key]) || [];

        segments.forEach((segment, index) => {
          if (!this.present(segment[1]) || !this.present(segment[2])) return;

          const start = Number(segment[1]);
          const end = Number(segment[2]);

          blocks.push({
            key: `s-${source.id}-${verse}-${index}`,
            left: start * this.pxPerMs,
            width: Math.max(2, (end - start) * this.pxPerMs),
            title: `${verse}:${segment[0]} — ${start}–${end} ms`,
          });
        });
      }

      return blocks;
    },
    scrollToCurrentAyah() {
      const scroller = this.$refs.scroller;
      const data = this.segments[`${this.chapter}:${this.currentVerseNumber}`];
      if (!scroller || !data || !this.present(data.timestamp_from)) return;

      const from = Number(data.timestamp_from);
      const to = this.present(data.timestamp_to) ? Number(data.timestamp_to) : from;
      const centerX = this.trackWidth - ((from + to) / 2) * this.pxPerMs;
      const left = Math.max(0, centerX - scroller.clientWidth / 2);

      scroller.scrollTo({ left, behavior: 'smooth' });
    },
    seek(event) {
      const track = this.$refs.track;
      if (!track || typeof player === 'undefined' || !player) return;

      const rect = track.getBoundingClientRect();
      const time = Math.max(0, (rect.right - event.clientX) / this.pxPerMs);

      player.currentTime = Math.max(0, time / 1000);
    },
  },
};
</script>

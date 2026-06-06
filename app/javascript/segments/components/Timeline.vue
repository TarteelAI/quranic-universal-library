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
        <template v-if="audioSrc">
          <label
              class="flex items-center gap-1 text-gray-600 cursor-pointer"
              data-controller="tooltip"
              title="Decodes the whole audio file to draw its waveform. This can be slow and memory-heavy for long surahs."
          >
            <input
                type="checkbox"
                :checked="waveformEnabled"
                @change="toggleWaveform"
                class="w-3 h-3 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            Waveform
          </label>
          <span v-if="!waveformEnabled" class="text-amber-500">⚠ may be slow for long audio</span>
        </template>

        <span v-if="waveformEnabled && waveformState === 'loading'" class="flex items-center gap-1 text-gray-500">
          <span class="inline-block w-3 h-3 border-2 border-gray-400 border-t-transparent rounded-full animate-spin"></span>
          decoding audio…
        </span>
        <span v-else-if="waveformEnabled && waveformState === 'error'" class="text-amber-500">waveform unavailable for this source</span>

        <button @click="scrollToCurrentTime" class="text-blue-600 hover:text-blue-700 font-medium">
          Jump to current time
        </button>
      </div>
    </div>

    <div ref="scroller" class="overflow-x-auto overflow-y-hidden">
      <div
          ref="track"
          class="relative timeline"
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

        <!-- waveform -->
        <canvas
            v-for="tile in waveformTiles"
            :key="tile.key"
            :ref="(el) => setTileRef(el, tile.index)"
            class="absolute pointer-events-none"
            :style="{ right: tile.left + 'px', width: tile.width + 'px', top: waveformTop + 'px', height: waveH + 'px' }"
        ></canvas>

        <!-- word blocks -->
        <div
            v-for="block in wordBlocks"
            :key="block.key"
            class="tl-word"
            :class="block.invalid ? 'tl-word--invalid' : (block.overlap ? 'tl-word--overlap' : (block.isCurrent ? 'tl-word--current' : ''))"
            :style="{ right: block.left + 'px', width: block.width + 'px', top: mainTop + 'px', height: mainH + 'px' }"
            @mouseenter="showWordTip($event, block)"
            @mousemove="showWordTip($event, block)"
            @mouseleave="hideWordTip"
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
        <div ref="playhead" class="absolute inset-y-0 w-px bg-gray-900 pointer-events-none" :style="{ right: playheadLeft + 'px' }">
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

    <div
        v-if="wordTip.show"
        class="fixed z-[200] px-2 py-1 text-[10px] font-medium text-white bg-gray-900 rounded shadow pointer-events-none whitespace-nowrap"
        :style="{ left: wordTip.x + 12 + 'px', top: wordTip.y + 12 + 'px' }"
    >
      {{ wordTip.text }}
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
      waveGap: 4,
      waveH: 36,
      laneH: 14,
      laneGap: 2,
      wordTip: { show: false, x: 0, y: 0, text: '' },
      tileWidth: 2000,
      waveformEnabled: false,
      waveformState: 'idle', // idle | loading | ready | error
    };
  },
  watch: {
    currentVerseNumber() {
      this.$nextTick(() => this.scrollToCurrentAyah());
    },
    currentTimestamp() {
      if (this.playing) this.followPlayhead();
    },
    showTimeline(visible) {
      if (visible) {
        if (this.waveformEnabled) this.loadWaveform();
        this.$nextTick(() => this.scrollToCurrentAyah());
      }
    },
    waveformEnabled(enabled) {
      if (enabled) {
        this.loadWaveform();
      } else {
        this.audioData = null;
        this.decodedSrc = null;
        this.waveformState = 'idle';
      }
    },
    audioSrc() {
      // A new audio source invalidates the decoded buffer.
      this.audioData = null;
      this.decodedSrc = null;
      this.waveformState = 'idle';
      if (this.waveformEnabled && this.showTimeline) this.loadWaveform();
    },
  },
  created() {
    // Kept off the reactive data so the decoded Float32Array isn't proxied
    // (proxied per-sample reads would make the draw loop pathologically slow).
    this.tileEls = {};
    this.audioData = null; // { channel: Float32Array, sampleRate }
    this.decodedSrc = null;
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
      'audioSrc',
      'playing',
    ]),
    segmentsLoaded() {
      return !!this.verseSegment;
    },
    waveformVisible() {
      return this.waveformEnabled && this.waveformState === 'ready';
    },
    waveformTop() {
      return this.mainTop + this.mainH + this.waveGap;
    },
    waveformReserved() {
      // Vertical space the waveform lane occupies, so lanes below it shift down.
      return this.waveformVisible ? this.waveGap + this.waveH : 0;
    },
    waveformTiles() {
      if (!this.waveformVisible) return [];

      const total = this.trackWidth;
      const count = Math.ceil(total / this.tileWidth);

      return Array.from({ length: count }, (_, i) => ({
        key: `wf-${i}`,
        index: i,
        left: i * this.tileWidth,
        width: Math.min(this.tileWidth, total - i * this.tileWidth),
      }));
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
            location: `${this.chapter}:${verse}:${segment[0]}`,
            title: `${this.chapter}:${verse}:${segment[0]} — ${start}–${end} ms`,
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
    showWordTip(event, block) {
      this.wordTip = { show: true, x: event.clientX, y: event.clientY, text: block.title };
    },
    hideWordTip() {
      this.wordTip.show = false;
    },
    laneTop(index) {
      return this.mainTop + this.mainH + 4 + this.waveformReserved + index * (this.laneH + this.laneGap);
    },
    zoomIn() {
      this.pxPerMs = Math.min(this.maxPxPerMs, Number((this.pxPerMs * 1.4).toFixed(4)));
      this.$nextTick(() => { this.scrollToCurrentAyah(); this.drawWaveform(); });
    },
    zoomOut() {
      this.pxPerMs = Math.max(this.minPxPerMs, Number((this.pxPerMs / 1.4).toFixed(4)));
      this.$nextTick(() => { this.scrollToCurrentAyah(); this.drawWaveform(); });
    },
    zoomReset() {
      this.pxPerMs = 0.1;
      this.$nextTick(() => { this.scrollToCurrentAyah(); this.drawWaveform(); });
    },
    setTileRef(el, index) {
      if (el) this.tileEls[index] = el;
    },
    toggleWaveform(event) {
      this.waveformEnabled = event.target.checked;
    },
    async loadWaveform() {
      const src = this.audioSrc;
      if (!src) return;

      if (this.decodedSrc === src && this.waveformState === 'ready') {
        this.$nextTick(() => this.drawWaveform());
        return;
      }
      if (this.waveformState === 'loading') return;

      this.waveformState = 'loading';

      try {
        const response = await fetch(src);
        const arrayBuffer = await response.arrayBuffer();
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        const ctx = new AudioCtx();
        const buffer = await ctx.decodeAudioData(arrayBuffer);

        // Mix to mono so a single peak pass covers the whole file.
        const channel = buffer.getChannelData(0);
        let mono = channel;
        if (buffer.numberOfChannels > 1) {
          const right = buffer.getChannelData(1);
          mono = new Float32Array(channel.length);
          for (let i = 0; i < channel.length; i++) mono[i] = (channel[i] + right[i]) / 2;
        }

        if (ctx.close) ctx.close();

        this.audioData = { channel: mono, sampleRate: buffer.sampleRate };
        this.decodedSrc = src;
        this.waveformState = 'ready';
        this.$nextTick(() => this.drawWaveform());
      } catch (e) {
        // Most likely a CORS-blocked remote URL; degrade gracefully.
        this.waveformState = 'error';
      }
    },
    drawWaveform() {
      if (this.waveformState !== 'ready' || !this.audioData) return;

      const { channel, sampleRate } = this.audioData;
      const dpr = window.devicePixelRatio || 1;
      const samplesPerPx = (sampleRate / 1000) / this.pxPerMs;
      const mid = this.waveH / 2;

      this.waveformTiles.forEach((tile) => {
        const canvas = this.tileEls[tile.index];
        if (!canvas) return;

        const w = tile.width;
        const h = this.waveH;
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);

        const c = canvas.getContext('2d');
        c.setTransform(dpr, 0, 0, dpr, 0, 0);
        c.clearRect(0, 0, w, h);
        c.fillStyle = 'rgba(37, 99, 235, 0.35)';

        for (let cx = 0; cx < w; cx++) {
          // RTL: distance from track right edge → time. The tile's right edge
          // sits at `tile.left`px from the track right edge.
          const distance = tile.left + (w - cx);
          const timeMs = distance / this.pxPerMs;
          const startSample = Math.floor((timeMs / 1000) * sampleRate);
          const endSample = Math.floor(startSample + samplesPerPx);

          let peak = 0;
          for (let s = startSample; s < endSample && s < channel.length; s++) {
            const value = Math.abs(channel[s]);
            if (value > peak) peak = value;
          }

          if (peak > 0) {
            const barHeight = Math.max(1, peak * mid);
            c.fillRect(cx, mid - barHeight, 1, barHeight * 2);
          }
        }
      });
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
    scrollToCurrentTime() {
      const scroller = this.$refs.scroller;
      if (!scroller) return;

      const centerX = this.trackWidth - this.currentTimestamp * this.pxPerMs;
      const left = Math.max(0, centerX - scroller.clientWidth / 2);

      scroller.scrollTo({ left, behavior: 'smooth' });
    },
    followPlayhead() {
      const scroller = this.$refs.scroller;
      const playhead = this.$refs.playhead;
      if (!scroller || !playhead) return;

      // Re-center only when the playhead drifts near the viewport edge, so the
      // timeline isn't constantly animating during steady playback. Visibility
      // is tested via geometry to stay clear of RTL scrollLeft quirks.
      const scrollerRect = scroller.getBoundingClientRect();
      const playheadRect = playhead.getBoundingClientRect();
      const margin = scrollerRect.width * 0.15;

      const outOfView = playheadRect.left < scrollerRect.left + margin ||
        playheadRect.right > scrollerRect.right - margin;
      if (!outOfView) return;

      const centerX = this.trackWidth - this.currentTimestamp * this.pxPerMs;
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

<style scoped>
.timeline{
  font-family: qpc-hafs;
  font-size: 15px;
}
.tl-word {
  position: absolute;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 0.125rem;
  border-width: 1px;
  border-style: solid;
  line-height: 1;
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  background-color: #dbeafe;
  border-color: #bfdbfe;
  color: #1e40af;
}

.tl-word--current {
  background-color: #bfdbfe;
  border-color: #60a5fa;
  color: #1e3a8a;
}

.tl-word--overlap {
  background-color: #ffedd5;
  border-color: #f97316;
  color: #9a3412;
}

.tl-word--invalid {
  background-color: #fee2e2;
  border-color: #f87171;
  color: #b91c1c;
}
</style>

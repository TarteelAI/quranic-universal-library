<template>
  <div class="cut-editor">
    <p v-if="loading" class="text-gray-500 text-sm">Loading surah…</p>
    <p v-else-if="loadError" class="text-red-600 text-sm">{{ loadError }}</p>

    <div v-else>
      <div class="flex flex-wrap items-center gap-2 mb-3 text-sm text-gray-600">
        <span class="font-medium text-gray-800">{{ recitation.name }} · surah {{ chapter.id }} {{ chapter.name }}</span>
        <span>· {{ fmt(durationMs) }}</span>
        <span class="text-xs text-gray-400 truncate max-w-xl" :title="sourceLabel">· {{ sourceLabel }}</span>
      </div>

      <!-- Detected returns to an earlier ayah -->
      <div class="border rounded p-3 mb-3">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-semibold text-sm">Detected repeats</h3>
          <span class="text-[11px] text-gray-400">
            timings from {{ repeats.timeline }}<template v-if="repeats.offset_ms"> (shifted {{ repeats.offset_ms }} ms)</template>
            <button class="ml-2 underline" @click="loadRepeats">re-check</button>
          </span>
        </div>
        <p v-if="repeatsError" class="text-xs text-red-600">{{ repeatsError }}</p>
        <p v-else-if="!repeats.episodes.length" class="text-xs text-gray-400">
          No return to an earlier ayah found. You can still drag on the waveform to cut any section.
        </p>
        <div v-for="(ep, i) in repeats.episodes" :key="i" class="border-t first:border-t-0 py-2">
          <div class="flex items-center gap-2 text-sm">
            <button class="text-indigo-700 hover:underline font-medium" @click="showRange(ep.start_ms, ep.end_ms)">
              {{ ep.verse_keys.join(", ") }}
            </button>
            <span class="text-gray-600">{{ ep.sequence.map(takeLabel).join(" → ") }}</span>
            <span class="text-gray-400 text-xs">{{ fmt(ep.start_ms) }}–{{ fmt(ep.end_ms) }}</span>
            <span v-if="ep.applied" class="text-[10px] px-1.5 rounded bg-green-100 text-green-700">cut added</span>
          </div>
          <div class="mt-1 space-y-1">
            <div v-for="(opt, j) in ep.options" :key="j" class="flex flex-wrap items-center gap-2 text-xs pl-3">
              <span class="text-gray-700">
                keep <b>{{ opt.result.map(takeLabel).join(" → ") }}</b>
                <span class="text-gray-400">(remove {{ opt.removes.map(takeLabel).join(", ") }}, {{ secs(opt.duration_ms) }}s)</span>
              </span>
              <button class="btn btn-xs btn-outline-secondary" @click="selectOption(opt)">select</button>
              <button class="btn btn-xs btn-outline-secondary" @click="playAcross(opt.start_ms, opt.end_ms)">▶ hear result</button>
              <button class="btn btn-xs btn-outline-danger" :disabled="busy" @click="addCut(opt.start_ms, opt.end_ms, noteFor(ep, opt))">add cut</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Whole surah overview: click to move the window -->
      <div class="relative h-5 rounded bg-gray-100 border mb-1 cursor-pointer select-none" ref="overview" @click="overviewClick">
        <div v-for="(ep, i) in repeats.episodes" :key="'e' + i"
             class="absolute top-0 bottom-0 bg-amber-300/70"
             :style="spanStyle(ep.start_ms, ep.end_ms, 0, durationMs, 2)"></div>
        <div v-for="c in cuts" :key="'c' + c.id"
             class="absolute top-0 bottom-0 bg-red-500/70"
             :style="spanStyle(c.target.start_ms, c.target.end_ms, 0, durationMs, 2)"></div>
        <div class="absolute top-0 bottom-0 border-2 border-indigo-600 rounded-sm"
             :style="spanStyle(winStart, winEnd, 0, durationMs, 4)"></div>
      </div>

      <!-- Waveform window -->
      <div class="flex items-center gap-1 mb-1 text-xs">
        <button class="btn btn-xs btn-outline-secondary" @click="pan(-0.5)">◀</button>
        <button class="btn btn-xs btn-outline-secondary" @click="pan(0.5)">▶</button>
        <button class="btn btn-xs btn-outline-secondary" @click="zoom(0.5)">＋ zoom</button>
        <button class="btn btn-xs btn-outline-secondary" @click="zoom(2)">－ zoom</button>
        <button v-if="sel" class="btn btn-xs btn-outline-secondary" @click="showRange(sel.start, sel.end)">fit selection</button>
        <span class="text-gray-500 ml-2">{{ fmt(winStart) }} – {{ fmt(winEnd) }} ({{ secs(winEnd - winStart) }}s)</span>
        <span class="ml-auto text-gray-400">drag to select · drag the edges to adjust · click to play from there</span>
      </div>
      <div ref="wrap" class="relative">
        <canvas ref="canvas" class="w-full block rounded border bg-gray-50"
                :style="{ height: canvasHeight + 'px', cursor: hoverCursor }"
                @pointerdown="down" @pointermove="move" @pointerup="up" @pointerleave="leave"></canvas>
        <div v-if="peaksLoading" class="absolute right-2 top-1 text-[10px] text-gray-400">loading waveform…</div>
      </div>

      <!-- Selection -->
      <div class="border rounded p-3 mt-2">
        <div v-if="!sel" class="text-xs text-gray-400">No selection. Drag across the waveform, or pick an option above.</div>
        <div v-else class="flex flex-wrap items-center gap-2 text-xs">
          <span class="font-medium text-sm">Selection</span>
          <label class="flex items-center gap-1">from
            <input type="number" step="0.01" class="form-control form-control-sm w-28" :value="(sel.start / 1000).toFixed(3)" @change="setEdge('start', $event.target.value)" />
          </label>
          <button class="btn btn-xs btn-outline-secondary" @click="nudge('start', -20)">-20ms</button>
          <button class="btn btn-xs btn-outline-secondary" @click="nudge('start', 20)">+20ms</button>
          <label class="flex items-center gap-1 ml-2">to
            <input type="number" step="0.01" class="form-control form-control-sm w-28" :value="(sel.end / 1000).toFixed(3)" @change="setEdge('end', $event.target.value)" />
          </label>
          <button class="btn btn-xs btn-outline-secondary" @click="nudge('end', -20)">-20ms</button>
          <button class="btn btn-xs btn-outline-secondary" @click="nudge('end', 20)">+20ms</button>
          <span class="text-gray-500 ml-2">{{ secs(sel.end - sel.start) }}s</span>
          <span v-if="selClash" class="text-red-600">overlaps an existing cut</span>
        </div>
        <div v-if="sel" class="flex flex-wrap items-center gap-2 mt-2">
          <button class="btn btn-sm btn-outline-secondary" @click="playRange(sel.start, sel.end)">▶ play selection</button>
          <button class="btn btn-sm btn-outline-secondary" @click="playAcross(sel.start, sel.end)">▶ hear without it</button>
          <input v-model="note" class="form-control form-control-sm w-64" placeholder="note (optional), e.g. repeated 48" />
          <button class="btn btn-sm btn-danger" :disabled="busy || selClash || sel.end - sel.start < 20" @click="addCut(sel.start, sel.end, note)">✂ Remove this section</button>
          <button class="btn btn-sm btn-link" @click="sel = null; draw()">clear</button>
        </div>
      </div>

      <div class="flex items-center gap-3 mt-2 text-xs">
        <audio ref="player" :src="audioUrl" controls preload="none" class="h-8" @play="startLoop" @pause="stopLoop"></audio>
        <label class="flex items-center gap-1"><input type="checkbox" v-model="skipCuts" /> skip cuts while playing</label>
      </div>

      <!-- Cuts + export -->
      <div class="border rounded p-3 mt-3">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-semibold text-sm">Cuts ({{ cuts.length }}) <span v-if="cuts.length" class="font-normal text-gray-500">· removes {{ secs(removedMs) }}s</span></h3>
          <div class="flex gap-1">
            <button class="btn btn-xs btn-outline-secondary" @click="undo" :disabled="!canUndo || busy">↶ undo</button>
            <button class="btn btn-xs btn-outline-secondary" @click="redo" :disabled="!canRedo || busy">redo ↷</button>
          </div>
        </div>
        <ol class="text-xs space-y-1">
          <li v-for="c in cuts" :key="c.id" class="flex items-center gap-2">
            <span class="inline-block px-1 rounded text-[10px] bg-red-100 text-red-700">cut</span>
            <button class="hover:underline" @click="showRange(c.target.start_ms, c.target.end_ms, true)">{{ fmt(c.target.start_ms) }} – {{ fmt(c.target.end_ms) }}</button>
            <span class="text-gray-500">{{ secs(c.target.end_ms - c.target.start_ms) }}s</span>
            <span class="text-gray-600">{{ c.note }}</span>
            <button class="btn btn-xs btn-outline-secondary ml-auto" @click="playAcross(c.target.start_ms, c.target.end_ms)">▶ hear</button>
            <button class="btn btn-xs btn-outline-danger" :disabled="busy" @click="removeOp(c)">remove</button>
          </li>
        </ol>
        <p v-if="!cuts.length" class="text-xs text-gray-400">No cuts yet.</p>
        <p v-if="otherOps" class="text-xs text-gray-500 mt-1">+ {{ otherOps }} word/sound repair(s) in this session, also applied on export.</p>

        <div class="mt-3 pt-3 border-t flex flex-wrap gap-2 items-center">
          <select v-model="bitrate" class="form-control form-control-sm w-24">
            <option>128k</option><option>192k</option><option>256k</option><option>320k</option>
          </select>
          <button class="btn btn-sm btn-dark" @click="exportMp3" :disabled="!operations.length || status === 'rendering'">
            {{ status === 'rendering' ? 'Rendering…' : 'Export final MP3' }}
          </button>
          <span v-if="status" class="text-xs" :class="status === 'failed' ? 'text-red-600' : 'text-gray-500'">{{ status }}</span>
          <a v-if="status === 'exported' && outputPath" :href="outputPath" class="btn btn-xs btn-success" download>⬇ Download final MP3</a>
          <span v-if="status === 'exported' && outputDurationMs" class="text-xs text-gray-500">{{ fmt(outputDurationMs) }} long</span>
        </div>
        <p v-if="status === 'exported' && outputPath" class="text-xs text-gray-500 mt-1">
          Output: {{ outputPath }}
          <audio :src="outputPath" controls preload="none" class="h-7 inline-block align-middle ml-2"></audio>
        </p>
        <p v-if="lastError" class="text-xs text-red-600 mt-1">{{ lastError }}</p>

        <div v-if="cuts.length" class="mt-3 pt-3 border-t text-xs">
          <button class="btn btn-sm btn-outline-primary" :disabled="busy" @click="applyToDrafts">Shift segment drafts to match the cuts</button>
          <span class="text-gray-500 ml-2">Drops the words inside each cut and moves later timings earlier, so highlighting matches the final file.</span>
          <p v-if="draftResult" class="mt-1" :class="draftResult.note ? 'text-amber-700' : 'text-green-700'">
            <template v-if="draftResult.note">{{ draftResult.note }}</template>
            <template v-else>
              Updated {{ draftResult.drafts }} draft(s), dropped {{ draftResult.words_dropped }} word(s), moved by up to {{ secs(draftResult.removed_ms) }}s.
              <template v-if="draftResult.reapproved">{{ draftResult.reapproved }} imported draft(s) set back to approved — re-import them.</template>
            </template>
          </p>
        </div>
      </div>

      <p v-if="message" class="text-xs text-blue-700 mt-2">{{ message }}</p>
    </div>
  </div>
</template>

<script>
const EDGE_PX = 7;
const CONTEXT_MS = 3000;

export default {
  props: {
    sessionId: { type: String, required: true },
    focusStartMs: { type: Number, default: null },
    focusEndMs: { type: Number, default: null }
  },

  emits: ["applied"],

  data() {
    return {
      loading: true,
      loadError: null,
      message: null,
      busy: false,
      recitation: {},
      chapter: {},
      sourceLabel: "",
      audioUrl: null,
      durationMs: 0,
      repeats: { timeline: "", offset_ms: 0, episodes: [], passes: [] },
      repeatsError: null,
      operations: [],
      canUndo: false,
      canRedo: false,
      status: null,
      outputPath: null,
      outputDurationMs: null,
      lastError: null,
      bitrate: "192k",
      pollTimer: null,
      winStart: 0,
      winEnd: 30000,
      peaks: [],
      peaksRange: null,
      peaksLoading: false,
      peaksTimer: null,
      sel: null,
      drag: null,
      hoverCursor: "crosshair",
      note: "",
      playhead: null,
      stopAt: null,
      jump: null,
      raf: null,
      skipCuts: true,
      canvasHeight: 150,
      draftResult: null
    };
  },

  computed: {
    base() { return `/audio_repair/sessions/${this.sessionId}`; },
    cuts() { return this.operations.filter((o) => o.kind === "cut").sort((a, b) => a.target.start_ms - b.target.start_ms); },
    otherOps() { return this.operations.length - this.cuts.length; },
    removedMs() { return this.cuts.reduce((sum, c) => sum + (c.target.end_ms - c.target.start_ms), 0); },
    selClash() {
      if (!this.sel) return false;
      return this.operations.some((o) => o.kind !== "vowel_repair" && o.target &&
        o.target.start_ms < this.sel.end && o.target.end_ms > this.sel.start);
    }
  },

  async mounted() {
    window.addEventListener("resize", this.draw);
    await this.load();
  },

  beforeUnmount() {
    window.removeEventListener("resize", this.draw);
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.stopLoop();
  },

  methods: {
    async api(url, { method = "GET", body = null } = {}) {
      const opts = { method, headers: { Accept: "application/json" } };
      if (body) {
        opts.headers["Content-Type"] = "application/json";
        opts.body = JSON.stringify(body);
      }
      if (method !== "GET") {
        const token = document.querySelector('meta[name="csrf-token"]');
        if (token) opts.headers["X-CSRF-Token"] = token.content;
      }
      const res = await fetch(url, opts);
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
      return data;
    },

    async load() {
      try {
        const d = await this.api(`${this.base}/data`);
        this.recitation = d.recitation || {};
        this.chapter = d.chapter || {};
        this.audioUrl = d.audio_url;
        this.durationMs = d.duration_ms || 0;
        this.sourceLabel = (d.source && d.source.label) || d.audio_url || "";
        this.applyState(d.session);
      } catch (e) {
        this.loadError = e.message;
      } finally {
        this.loading = false;
      }
      await this.loadRepeats();
      this.$nextTick(() => {
        if (this.focusStartMs != null) this.showRange(this.focusStartMs, this.focusEndMs || this.focusStartMs + 10000);
        else if (this.repeats.episodes.length) this.showRange(this.repeats.episodes[0].start_ms, this.repeats.episodes[0].end_ms);
        else this.setWindow(0, Math.min(30000, this.durationMs || 30000));
      });
    },

    async loadRepeats() {
      this.repeatsError = null;
      try {
        this.repeats = await this.api(`${this.base}/repeats`);
        if (!this.durationMs && this.repeats.passes.length) {
          this.durationMs = this.repeats.passes[this.repeats.passes.length - 1].end_ms + 2000;
        }
      } catch (e) {
        this.repeatsError = e.message;
      }
      this.draw();
    },

    applyState(s) {
      if (!s) return;
      this.operations = s.operations || [];
      this.canUndo = s.can_undo;
      this.canRedo = s.can_redo;
      this.status = s.status;
      this.outputPath = s.output_path;
      this.outputDurationMs = s.output_duration_ms;
      this.lastError = s.last_error;
      if (this.status === "rendering") this.startPolling();
      this.$emit("applied", s);
      this.draw();
    },

    // ---- formatting ---------------------------------------------------------

    fmt(ms) {
      if (ms == null) return "–";
      const total = ms / 1000;
      const m = Math.floor(total / 60);
      const s = (total - m * 60).toFixed(2).padStart(5, "0");
      return `${m}:${s}`;
    },
    secs(ms) { return (ms / 1000).toFixed(2); },
    takeLabel(label) { return label.replace(/ \(take (\d+)\)/, (_m, n) => `·${n}`); },
    noteFor(ep, opt) { return `repeat ${ep.verse_keys.join("–")}: remove ${opt.removes.join(", ")}`; },
    spanStyle(a, b, from, to, minPx) {
      const span = Math.max(1, to - from);
      const left = ((a - from) / span) * 100;
      const width = ((b - a) / span) * 100;
      return { left: `${left}%`, width: `max(${width}%, ${minPx || 1}px)` };
    },

    // ---- window -------------------------------------------------------------

    setWindow(a, b) {
      const dur = this.durationMs || b;
      let span = Math.max(1000, b - a);
      a = Math.max(0, a);
      if (dur && a + span > dur) a = Math.max(0, dur - span);
      if (dur) span = Math.min(span, dur);
      this.winStart = Math.round(a);
      this.winEnd = Math.round(a + span);
      this.draw();
      this.schedulePeaks();
    },
    showRange(a, b, select = false) {
      const pad = Math.max(1500, (b - a) * 0.15);
      this.setWindow(a - pad, b + pad);
      if (select) this.sel = { start: a, end: b };
    },
    selectOption(opt) {
      this.sel = { start: opt.start_ms, end: opt.end_ms };
      this.note = "";
      this.showRange(opt.start_ms, opt.end_ms);
    },
    pan(frac) {
      const span = this.winEnd - this.winStart;
      this.setWindow(this.winStart + span * frac, this.winEnd + span * frac);
    },
    zoom(factor) {
      const mid = this.sel ? (this.sel.start + this.sel.end) / 2 : (this.winStart + this.winEnd) / 2;
      const span = (this.winEnd - this.winStart) * factor;
      this.setWindow(mid - span / 2, mid + span / 2);
    },
    overviewClick(e) {
      const rect = this.$refs.overview.getBoundingClientRect();
      const t = ((e.clientX - rect.left) / rect.width) * this.durationMs;
      const span = this.winEnd - this.winStart;
      this.setWindow(t - span / 2, t + span / 2);
    },

    schedulePeaks() {
      clearTimeout(this.peaksTimer);
      this.peaksTimer = setTimeout(this.loadPeaks, 150);
    },
    async loadPeaks() {
      const canvas = this.$refs.canvas;
      if (!canvas) return;
      const buckets = Math.min(1200, Math.max(100, Math.round(canvas.clientWidth)));
      const q = new URLSearchParams({ start_ms: this.winStart, end_ms: this.winEnd, buckets });
      const key = `${this.winStart}-${this.winEnd}`;
      this.peaksLoading = true;
      try {
        const d = await this.api(`${this.base}/peaks?${q}`);
        if (key === `${this.winStart}-${this.winEnd}`) {
          this.peaks = d.peaks || [];
          this.peaksRange = [this.winStart, this.winEnd];
        }
      } catch (e) {
        this.message = `Waveform: ${e.message}`;
      } finally {
        this.peaksLoading = false;
        this.draw();
      }
    },

    // ---- drawing ------------------------------------------------------------

    x(t, w) { return ((t - this.winStart) / (this.winEnd - this.winStart)) * w; },
    t(px, w) { return this.winStart + (px / w) * (this.winEnd - this.winStart); },

    draw() {
      const canvas = this.$refs.canvas;
      if (!canvas) return;
      const dpr = window.devicePixelRatio || 1;
      const cssW = canvas.clientWidth || 800;
      const cssH = this.canvasHeight;
      if (canvas.width !== Math.round(cssW * dpr)) canvas.width = Math.round(cssW * dpr);
      if (canvas.height !== Math.round(cssH * dpr)) canvas.height = Math.round(cssH * dpr);
      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const w = cssW;
      const h = cssH;
      const laneH = 22;
      ctx.clearRect(0, 0, w, h);

      // ayah takes along the top
      ctx.font = "11px sans-serif";
      ctx.textBaseline = "middle";
      for (const p of this.repeats.passes) {
        if (p.end_ms < this.winStart || p.start_ms > this.winEnd) continue;
        const x0 = this.x(p.start_ms, w);
        const x1 = this.x(p.end_ms, w);
        ctx.fillStyle = p.takes > 1 ? "rgba(245, 158, 11, 0.35)" : (p.verse_number % 2 ? "rgba(99, 102, 241, 0.18)" : "rgba(16, 185, 129, 0.18)");
        ctx.fillRect(x0, 2, Math.max(1, x1 - x0), laneH - 4);
        const label = p.takes > 1 ? `${p.verse_number}·${p.take}` : `${p.verse_number}`;
        ctx.fillStyle = "#374151";
        if (x1 - x0 > 14) ctx.fillText(label, Math.max(x0, 0) + 3, laneH / 2);
      }

      // waveform
      const top = laneH;
      const wh = h - laneH;
      const mid = top + wh / 2;
      if (this.peaks.length && this.peaksRange) {
        const [pa, pb] = this.peaksRange;
        const per = (pb - pa) / this.peaks.length;
        ctx.fillStyle = "rgba(37, 99, 235, 0.65)";
        this.peaks.forEach((p, i) => {
          const a = this.x(pa + i * per, w);
          const b = this.x(pa + (i + 1) * per, w);
          const bh = Math.max(1, (p / 100) * (wh - 4));
          ctx.fillRect(a, mid - bh / 2, Math.max(1, b - a - 0.5), bh);
        });
      }

      // existing cuts
      for (const c of this.cuts) {
        const a = this.x(c.target.start_ms, w);
        const b = this.x(c.target.end_ms, w);
        if (b < 0 || a > w) continue;
        ctx.fillStyle = "rgba(239, 68, 68, 0.28)";
        ctx.fillRect(a, top, b - a, wh);
        ctx.strokeStyle = "rgba(220, 38, 38, 0.9)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let xx = a - wh; xx < b; xx += 10) {
          ctx.moveTo(Math.max(xx, a), top + Math.max(0, a - xx));
          ctx.lineTo(Math.min(xx + wh, b), top + Math.min(wh, b - xx));
        }
        ctx.stroke();
      }

      // selection
      if (this.sel) {
        const a = this.x(this.sel.start, w);
        const b = this.x(this.sel.end, w);
        ctx.fillStyle = this.selClash ? "rgba(239, 68, 68, 0.25)" : "rgba(79, 70, 229, 0.22)";
        ctx.fillRect(a, 0, b - a, h);
        ctx.fillStyle = "rgba(79, 70, 229, 1)";
        ctx.fillRect(a - 1, 0, 2, h);
        ctx.fillRect(b - 1, 0, 2, h);
        ctx.fillRect(a - 4, h / 2 - 10, 8, 20);
        ctx.fillRect(b - 4, h / 2 - 10, 8, 20);
      }

      // playhead
      if (this.playhead != null && this.playhead >= this.winStart && this.playhead <= this.winEnd) {
        ctx.fillStyle = "#111827";
        ctx.fillRect(this.x(this.playhead, w), 0, 1.5, h);
      }
    },

    // ---- mouse --------------------------------------------------------------

    pos(e) {
      const rect = this.$refs.canvas.getBoundingClientRect();
      return { px: e.clientX - rect.left, w: rect.width };
    },
    hit(px, w) {
      if (!this.sel) return "new";
      const a = this.x(this.sel.start, w);
      const b = this.x(this.sel.end, w);
      if (Math.abs(px - a) <= EDGE_PX) return "start";
      if (Math.abs(px - b) <= EDGE_PX) return "end";
      if (px > a && px < b) return "move";
      return "new";
    },
    down(e) {
      const { px, w } = this.pos(e);
      const t = this.clampT(this.t(px, w));
      const mode = this.hit(px, w);
      this.$refs.canvas.setPointerCapture(e.pointerId);
      this.drag = { mode, startPx: px, anchor: t, orig: this.sel ? { ...this.sel } : null, moved: false };
    },
    move(e) {
      const { px, w } = this.pos(e);
      if (!this.drag) {
        const mode = this.hit(px, w);
        this.hoverCursor = mode === "start" || mode === "end" ? "ew-resize" : mode === "move" ? "grab" : "crosshair";
        return;
      }
      if (Math.abs(px - this.drag.startPx) > 3) this.drag.moved = true;
      if (!this.drag.moved) return;
      const t = this.clampT(this.t(px, w));
      const d = this.drag;
      if (d.mode === "new") {
        this.sel = { start: Math.round(Math.min(d.anchor, t)), end: Math.round(Math.max(d.anchor, t)) };
      } else if (d.mode === "start") {
        this.sel = { start: Math.round(Math.min(t, d.orig.end - 10)), end: d.orig.end };
      } else if (d.mode === "end") {
        this.sel = { start: d.orig.start, end: Math.round(Math.max(t, d.orig.start + 10)) };
      } else if (d.mode === "move") {
        const delta = t - d.anchor;
        const len = d.orig.end - d.orig.start;
        const start = Math.round(Math.min(Math.max(0, d.orig.start + delta), (this.durationMs || Infinity) - len));
        this.sel = { start, end: start + len };
      }
      this.draw();
    },
    up(e) {
      const d = this.drag;
      this.drag = null;
      if (!d) return;
      if (!d.moved) {
        // A click: play from here.
        this.playFrom(d.anchor);
      }
    },
    leave() { if (!this.drag) this.hoverCursor = "crosshair"; },
    clampT(t) { return Math.max(0, Math.min(this.durationMs || t, t)); },

    setEdge(edge, value) {
      const ms = Math.round(parseFloat(value) * 1000);
      if (Number.isNaN(ms) || !this.sel) return;
      const next = { ...this.sel, [edge]: ms };
      if (next.end <= next.start) return;
      this.sel = next;
      this.draw();
    },
    nudge(edge, ms) {
      if (!this.sel) return;
      const next = { ...this.sel, [edge]: this.sel[edge] + ms };
      if (next.end <= next.start || next.start < 0) return;
      this.sel = next;
      this.draw();
    },

    // ---- playback -----------------------------------------------------------

    player() { return this.$refs.player; },
    async playFrom(ms, stopAt = null, jump = null) {
      const p = this.player();
      if (!p) return;
      this.stopAt = stopAt;
      this.jump = jump;
      try {
        p.currentTime = ms / 1000;
        await p.play();
      } catch (e) {
        this.message = `Playback: ${e.message}`;
      }
    },
    playRange(a, b) { this.playFrom(a, b); },
    // Context before the cut, then straight to the audio after it.
    playAcross(a, b) {
      this.playFrom(Math.max(0, a - CONTEXT_MS), b + CONTEXT_MS, { from: a, to: b });
    },
    startLoop() {
      this.stopLoop();
      const tick = () => {
        const p = this.player();
        if (!p) return;
        let ms = p.currentTime * 1000;
        if (this.jump && ms >= this.jump.from && ms < this.jump.to) {
          p.currentTime = this.jump.to / 1000;
          ms = this.jump.to;
          this.jump = null;
        } else if (this.skipCuts) {
          const c = this.cuts.find((c) => ms >= c.target.start_ms && ms < c.target.end_ms - 30);
          if (c) { p.currentTime = c.target.end_ms / 1000; ms = c.target.end_ms; }
        }
        if (this.stopAt != null && ms >= this.stopAt) {
          p.pause();
          this.stopAt = null;
        }
        this.playhead = ms;
        if (ms > this.winEnd || ms < this.winStart) {
          const span = this.winEnd - this.winStart;
          if (!this.drag) this.setWindow(ms - span * 0.1, ms + span * 0.9);
        }
        this.draw();
        if (!p.paused) this.raf = requestAnimationFrame(tick);
      };
      this.raf = requestAnimationFrame(tick);
    },
    stopLoop() {
      if (this.raf) cancelAnimationFrame(this.raf);
      this.raf = null;
    },

    // ---- edits --------------------------------------------------------------

    async addCut(start, end, note) {
      this.busy = true;
      this.message = null;
      try {
        const op = { kind: "cut", target: { start_ms: Math.round(start), end_ms: Math.round(end) } };
        if (note) op.note = note;
        const d = await this.api(`${this.base}/add_operation`, { method: "POST", body: { operation: op } });
        this.applyState(d);
        this.sel = null;
        this.note = "";
        this.message = `Cut added (${this.secs(end - start)}s). Export to get the final file.`;
        await this.loadRepeats();
      } catch (e) {
        this.message = e.message;
      } finally {
        this.busy = false;
      }
    },
    async removeOp(op) {
      this.busy = true;
      try {
        this.applyState(await this.api(`${this.base}/remove_operation`, { method: "POST", body: { operation_id: op.id } }));
        await this.loadRepeats();
      } catch (e) {
        this.message = e.message;
      } finally {
        this.busy = false;
      }
    },
    async undo() { this.applyState(await this.api(`${this.base}/undo`, { method: "POST" })); this.loadRepeats(); },
    async redo() { this.applyState(await this.api(`${this.base}/redo`, { method: "POST" })); this.loadRepeats(); },

    async exportMp3() {
      try {
        this.applyState(await this.api(`${this.base}/export`, { method: "POST", body: { bitrate: this.bitrate } }));
      } catch (e) {
        this.message = e.message;
      }
    },
    startPolling() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(async () => {
        try {
          const s = await this.api(`${this.base}/status`);
          this.applyState(s);
          if (s.status !== "rendering") {
            clearInterval(this.pollTimer);
            this.pollTimer = null;
          }
        } catch (e) {
          clearInterval(this.pollTimer);
          this.pollTimer = null;
        }
      }, 2000);
    },

    async applyToDrafts() {
      const total = this.secs(this.removedMs);
      if (!confirm(`Shift this surah's segment drafts for ${this.cuts.length} cut(s) (${total}s)? Words inside the cuts are dropped.`)) return;
      this.busy = true;
      try {
        this.draftResult = await this.api(`${this.base}/apply_cuts_to_drafts`, { method: "POST" });
      } catch (e) {
        this.message = e.message;
      } finally {
        this.busy = false;
      }
    }
  }
};
</script>

<template>
  <div class="ingest-trim border rounded p-3 bg-gray-50">
    <div class="flex items-center justify-between mb-2">
      <div class="text-sm font-semibold">
        Surah {{ item.chapter_id }} · {{ item.name }}
        <span class="text-gray-400 font-normal">{{ fmt(item.source_duration_ms) }}</span>
      </div>
      <button class="text-gray-400 hover:text-gray-700 text-sm" @click="$emit('close')">✕ close</button>
    </div>

    <div v-if="error" class="text-xs text-red-700 bg-red-50 border border-red-200 rounded p-2 mb-2">{{ error }}</div>

    <p class="text-[11px] text-gray-500 mb-2">
      Click the waveform to seek · drag the red line to move the cut · playing the local downloaded file
    </p>

    <!-- ===== Head (basmala) ===== -->
    <div v-if="item.expects_head_trim">
      <div class="flex items-baseline justify-between">
        <span class="text-xs font-semibold">Opening — where the basmala ends</span>
        <span class="text-xs" :class="confidenceClass">{{ confidenceLabel }}</span>
      </div>
      <p v-if="headReason" class="text-[11px] text-gray-500 mb-1">{{ headReason }}</p>

      <canvas
        ref="headCanvas"
        class="w-full border rounded bg-white"
        height="90"
        :style="{ cursor: dragging === 'head' ? 'grabbing' : 'pointer' }"
        @mousedown="onDown($event, 'head')"
      ></canvas>

      <div class="flex items-center gap-2 flex-wrap mt-2">
        <span class="text-xs text-gray-600 font-mono">cut {{ fmt(startMs) }}</span>
        <span class="text-xs text-gray-400 font-mono">· at {{ fmt(playheadMs) }}</span>
        <button v-for="n in nudges" :key="'h' + n" class="btn btn-sm btn-outline-secondary" @click="nudge('head', n)">
          {{ n > 0 ? '+' : '' }}{{ n }}ms
        </button>
        <button class="btn btn-sm btn-outline-secondary" @click="setCutToPlayhead('head')">Cut here</button>
        <button class="btn btn-sm btn-outline-secondary" @click="play(0, startMs)">▶ opening</button>
        <button class="btn btn-sm btn-dark" @click="play(startMs, startMs + 6000)">▶ after the cut</button>
        <button class="btn btn-sm btn-outline-secondary" @click="togglePlay">{{ playing ? '❚❚' : '▶' }}</button>
        <button class="btn btn-sm btn-outline-secondary" @click="stop">■</button>
      </div>

      <div v-if="alternatives.length" class="mt-2 text-xs">
        <span class="text-gray-500">Other candidates:</span>
        <button
          v-for="alt in alternatives"
          :key="alt.cut_ms"
          class="btn btn-sm btn-outline-secondary ml-1"
          @click="startMs = alt.cut_ms; drawHead()"
        >
          {{ fmt(alt.cut_ms) }}
        </button>
      </div>
    </div>
    <p v-else class="text-xs text-gray-600">
      This surah has no preceding basmala to remove, so nothing is cut from the opening.
    </p>

    <!-- ===== Tail (du'a) ===== -->
    <div class="mt-4 pt-3 border-t">
      <label class="flex items-start gap-2 text-xs">
        <input v-model="trimTail" type="checkbox" class="mt-0.5" @change="onTailToggle" />
        <span>
          <span class="font-semibold">Also cut a closing du'a</span>
          <span v-if="tailCandidate" class="text-gray-500"> — found {{ tailCandidate.reason }}</span>
          <span v-else class="text-gray-400"> — nothing obvious found</span>
          <div class="text-[11px] text-amber-800 bg-amber-50 border border-amber-200 rounded p-1.5 mt-1">
            Check this by ear before approving. A passage after a pause is usually the closing ayahs,
            not a du'a — Al-Baqarah's last two ayahs are themselves a long supplication after a clear
            pause. Cutting those would remove Qur'anic text.
          </div>
        </span>
      </label>

      <div v-if="trimTail">
        <canvas
          ref="tailCanvas"
          class="w-full border rounded bg-white mt-2"
          height="90"
          :style="{ cursor: dragging === 'tail' ? 'grabbing' : 'pointer' }"
          @mousedown="onDown($event, 'tail')"
        ></canvas>
        <div class="flex items-center gap-2 flex-wrap mt-2">
          <span class="text-xs text-gray-600 font-mono">cut {{ fmt(endMs) }}</span>
          <button v-for="n in nudges" :key="'t' + n" class="btn btn-sm btn-outline-secondary" @click="nudge('tail', n)">
            {{ n > 0 ? '+' : '' }}{{ n }}ms
          </button>
          <button class="btn btn-sm btn-outline-secondary" @click="setCutToPlayhead('tail')">Cut here</button>
          <button class="btn btn-sm btn-outline-secondary" @click="play(endMs - 6000, endMs)">▶ before the cut</button>
          <button class="btn btn-sm btn-dark" @click="play(endMs, endMs + 8000)">▶ what gets removed</button>
          <button class="btn btn-sm btn-outline-secondary" @click="stop">■</button>
        </div>
      </div>
    </div>

    <!-- ===== Approve ===== -->
    <div class="mt-4 pt-3 border-t">
      <div class="flex items-center gap-2 flex-wrap">
        <button class="btn btn-sm btn-dark" :disabled="working" @click="approve">
          {{ working ? 'Working…' : 'Approve & encode' }}
        </button>
        <button class="btn btn-sm btn-outline-secondary" :disabled="working" @click="redetect">Re-detect</button>
        <button
          class="btn btn-sm btn-outline-secondary"
          :disabled="working"
          title="Encode the file as it is, with no cut"
          @click="approveWithoutTrim"
        >
          Encode without trimming
        </button>
        <span class="text-xs text-gray-600">
          Keeps {{ fmt(endMs - startMs) }} of {{ fmt(item.source_duration_ms) }}
          <span v-if="removedMs > 0" class="text-gray-400">· removes {{ fmt(removedMs) }}</span>
        </span>
      </div>

      <!-- Encoding runs in the background, so the panel reports which step it
           is on rather than leaving the button looking stuck. -->
      <div v-if="working" class="mt-2">
        <div class="flex justify-between text-xs text-gray-600 mb-1">
          <span>
            {{ stageLabel }}
            <span v-if="stage" class="text-gray-400">· step {{ stage.done + 1 }} of {{ stage.total }}</span>
          </span>
          <span class="text-gray-400 font-mono">{{ elapsedLabel }}</span>
        </div>
        <div class="w-full bg-gray-200 rounded h-1.5 overflow-hidden">
          <div
            class="h-1.5 bg-indigo-600 transition-all duration-500"
            :class="stagePercent === null ? 'animate-pulse w-1/3' : ''"
            :style="stagePercent === null ? {} : { width: stagePercent + '%' }"
          ></div>
        </div>
        <p class="text-[11px] text-gray-500 mt-1">
          A long surah takes a while to encode to every format. You can leave this panel open or come back to it.
        </p>
      </div>
    </div>

    <!-- ===== Result / channel checks ===== -->
    <div v-if="item.checks && Object.keys(item.checks).length" class="mt-3 pt-3 border-t">
      <div class="text-xs font-semibold mb-1">Checks</div>
      <div class="grid md:grid-cols-2 gap-2 text-xs">
        <div class="flex items-center gap-2">
          <span :class="item.checks.channels_ok ? 'text-green-700' : 'text-red-700'">
            {{ item.checks.channels_ok ? '✓' : '✕' }}
          </span>
          <span>
            Mono/stereo
            <span v-if="item.checks.mono_loss_db != null" class="text-gray-500">
              — summing to mono loses {{ Number(item.checks.mono_loss_db).toFixed(1) }} dB
            </span>
            <span v-else-if="item.checks.note" class="text-gray-500">— {{ item.checks.note }}</span>
          </span>
        </div>
        <div class="flex items-center gap-2">
          <span :class="item.checks.duration_ok ? 'text-green-700' : 'text-red-700'">
            {{ item.checks.duration_ok ? '✓' : '✕' }}
          </span>
          <span>
            Duration
            <span v-if="item.checks.duration_drift_ms != null" class="text-gray-500">
              — {{ item.checks.duration_drift_ms }}ms from expected
            </span>
          </span>
        </div>
      </div>
      <div v-if="item.output_url" class="mt-2">
        <audio :src="item.output_url" controls class="w-full h-8"></audio>
        <p class="text-[11px] text-gray-500 mt-1">
          The encoded file. Play it on a mono speaker (or with your system set to mono) to confirm nothing drops out.
        </p>
      </div>
    </div>
  </div>
</template>

<script>
const HEAD_WINDOW_MS = 30000;
const TAIL_WINDOW_MS = 40000;
const HANDLE_GRAB_PX = 7;

export default {
  name: "IngestTrim",
  props: {
    item: { type: Object, required: true },
    itemUrl: { type: String, required: true },
    detectUrl: { type: String, required: true },
    approveUrl: { type: String, required: true }
  },
  emits: ["close", "updated"],
  data() {
    return {
      startMs: this.item.trim_start_ms || 0,
      endMs: this.item.trim_end_ms || this.item.source_duration_ms,
      trimTail: false,
      headPeaks: [],
      tailPeaks: [],
      busy: false,
      error: null,
      audio: null,
      playing: false,
      playheadMs: 0,
      stopAt: null,
      dragging: null,
      rafId: null,
      startedAt: null,
      now: Date.now(),
      clockTimer: null,
      nudges: [-500, -100, -10, 10, 100, 500]
    };
  },
  computed: {
    detail() {
      return this.item.trim_detail || {};
    },
    headReason() {
      return this.detail.head ? this.detail.head.reason : null;
    },
    tailCandidate() {
      return this.detail.tail || null;
    },
    alternatives() {
      return this.detail.head_alternatives || [];
    },
    stage() {
      return this.item.progress_stage || null;
    },
    // Busy covers the request itself; item.working covers the background job
    // that outlives it, which is the part that used to give no feedback.
    working() {
      return this.busy || !!this.item.working;
    },
    stageLabel() {
      if (this.stage) return this.stage.label;
      return this.busy ? "submitting" : "working";
    },
    stagePercent() {
      if (!this.stage || !this.stage.total) return null;
      return Math.round((this.stage.done / this.stage.total) * 100);
    },
    elapsedLabel() {
      if (!this.startedAt) return "";
      const secs = Math.floor((this.now - this.startedAt) / 1000);
      const m = Math.floor(secs / 60);
      return m > 0 ? `${m}m ${secs % 60}s` : `${secs}s`;
    },
    removedMs() {
      return this.item.source_duration_ms - (this.endMs - this.startMs);
    },
    confidenceLabel() {
      const c = this.item.trim_confidence;
      if (c == null) return "not detected yet";
      if (c >= 0.7) return `confident (${c})`;
      if (c >= 0.45) return `uncertain (${c}) — check by ear`;
      return `low confidence (${c}) — check by ear`;
    },
    confidenceClass() {
      const c = this.item.trim_confidence;
      if (c == null) return "text-gray-400";
      return c >= 0.7 ? "text-green-700" : c >= 0.45 ? "text-amber-700" : "text-red-700";
    }
  },
  watch: {
    working(isWorking) {
      if (isWorking && !this.clockTimer) {
        this.startedAt = this.startedAt || Date.now();
        this.clockTimer = setInterval(() => {
          this.now = Date.now();
        }, 1000);
      } else if (!isWorking) {
        clearInterval(this.clockTimer);
        this.clockTimer = null;
        this.startedAt = null;
      }
    }
  },
  mounted() {
    this.loadPeaks();
    // Dragging continues outside the canvas.
    window.addEventListener("mousemove", this.onMove);
    window.addEventListener("mouseup", this.onUp);
  },
  beforeUnmount() {
    this.stop();
    clearInterval(this.clockTimer);
    window.removeEventListener("mousemove", this.onMove);
    window.removeEventListener("mouseup", this.onUp);
  },
  methods: {
    fmt(ms) {
      if (ms == null) return "—";
      const total = ms / 1000;
      const m = Math.floor(total / 60);
      const s = total % 60;
      return m > 0 ? `${m}:${s.toFixed(2).padStart(5, "0")}` : `${s.toFixed(2)}s`;
    },

    async api(url, { method = "GET", body = null } = {}) {
      const opts = { method, headers: { Accept: "application/json" } };
      if (method !== "GET") {
        const token = document.querySelector('meta[name="csrf-token"]');
        if (token) opts.headers["X-CSRF-Token"] = token.content;
        if (body) opts.body = body;
      }
      const res = await fetch(url, opts);
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
      return data;
    },

    async loadPeaks() {
      try {
        const head = await this.api(`${this.item.peaks_url}&start_ms=0&end_ms=${HEAD_WINDOW_MS}&buckets=600`);
        this.headPeaks = head.peaks;
        this.$nextTick(this.drawHead);
      } catch (e) {
        this.error = e.message;
      }
    },

    async loadTailPeaks() {
      const from = Math.max(0, this.item.source_duration_ms - TAIL_WINDOW_MS);
      try {
        const tail = await this.api(
          `${this.item.peaks_url}&start_ms=${from}&end_ms=${this.item.source_duration_ms}&buckets=600`
        );
        this.tailPeaks = tail.peaks;
        this.$nextTick(this.drawTail);
      } catch (e) {
        this.error = e.message;
      }
    },

    // ---- window maths -------------------------------------------------------

    windowFor(which) {
      if (which === "head") return [0, Math.min(HEAD_WINDOW_MS, this.item.source_duration_ms)];
      return [Math.max(0, this.item.source_duration_ms - TAIL_WINDOW_MS), this.item.source_duration_ms];
    },

    msAtX(which, canvas, clientX) {
      const [from, to] = this.windowFor(which);
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(Math.max((clientX - rect.left) / rect.width, 0), 1);
      return Math.round(from + ratio * (to - from));
    },

    xForMs(which, width, ms) {
      const [from, to] = this.windowFor(which);
      return ((ms - from) / (to - from)) * width;
    },

    // ---- drawing ------------------------------------------------------------

    draw(which) {
      const canvas = which === "head" ? this.$refs.headCanvas : this.$refs.tailCanvas;
      const peaks = which === "head" ? this.headPeaks : this.tailPeaks;
      if (!canvas || !peaks.length) return;

      const dpr = window.devicePixelRatio || 1;
      const width = canvas.clientWidth;
      canvas.width = width * dpr;
      canvas.height = 90 * dpr;
      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, 90);

      const keepLeft = which === "tail";
      const markerMs = which === "head" ? this.startMs : this.endMs;
      const markerX = this.xForMs(which, width, markerMs);

      // Shade the part that gets removed.
      ctx.fillStyle = "rgba(239, 68, 68, 0.10)";
      if (keepLeft) ctx.fillRect(markerX, 0, width - markerX, 90);
      else ctx.fillRect(0, 0, markerX, 90);

      const step = width / peaks.length;
      peaks.forEach((p, i) => {
        const x = i * step;
        const removed = keepLeft ? x >= markerX : x < markerX;
        ctx.fillStyle = removed ? "#d1d5db" : "#4f46e5";
        const h = (p / 100) * 80;
        ctx.fillRect(x, 45 - h / 2, Math.max(step - 0.5, 0.5), h || 1);
      });

      // Drawn under the cut marker so the cut stays readable.
      const [from, to] = this.windowFor(which);
      if (this.playheadMs >= from && this.playheadMs <= to) {
        const px = this.xForMs(which, width, this.playheadMs);
        ctx.strokeStyle = "#111827";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(px, 0);
        ctx.lineTo(px, 90);
        ctx.stroke();
        ctx.fillStyle = "#111827";
        ctx.beginPath();
        ctx.moveTo(px - 4, 90);
        ctx.lineTo(px + 4, 90);
        ctx.lineTo(px, 82);
        ctx.fill();
      }

      // Cut marker with a grab handle at the top.
      ctx.strokeStyle = "#dc2626";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(markerX, 0);
      ctx.lineTo(markerX, 90);
      ctx.stroke();
      ctx.fillStyle = "#dc2626";
      ctx.fillRect(markerX - 4, 0, 8, 10);
    },

    drawHead() {
      this.draw("head");
    },

    drawTail() {
      this.draw("tail");
    },

    redraw() {
      this.drawHead();
      if (this.trimTail) this.drawTail();
    },

    // ---- canvas interaction -------------------------------------------------

    // Near the red line: drag the cut. Anywhere else: seek.
    onDown(event, which) {
      const canvas = event.currentTarget;
      const markerMs = which === "head" ? this.startMs : this.endMs;
      const markerX = this.xForMs(which, canvas.clientWidth, markerMs);
      const rect = canvas.getBoundingClientRect();
      const x = event.clientX - rect.left;

      if (Math.abs(x - markerX) <= HANDLE_GRAB_PX) {
        this.dragging = which;
        event.preventDefault();
        return;
      }
      this.seekTo(this.msAtX(which, canvas, event.clientX));
    },

    onMove(event) {
      if (!this.dragging) return;
      const canvas = this.dragging === "head" ? this.$refs.headCanvas : this.$refs.tailCanvas;
      if (!canvas) return;
      const ms = this.msAtX(this.dragging, canvas, event.clientX);
      if (this.dragging === "head") this.startMs = Math.max(0, ms);
      else this.endMs = Math.min(this.item.source_duration_ms, ms);
      this.redraw();
    },

    onUp() {
      this.dragging = null;
    },

    nudge(which, ms) {
      if (which === "head") this.startMs = Math.max(0, this.startMs + ms);
      else this.endMs = Math.min(this.item.source_duration_ms, this.endMs + ms);
      this.redraw();
    },

    setCutToPlayhead(which) {
      if (which === "head") this.startMs = Math.round(this.playheadMs);
      else this.endMs = Math.round(this.playheadMs);
      this.redraw();
    },

    onTailToggle() {
      if (this.trimTail) {
        this.endMs = this.tailCandidate ? this.tailCandidate.cut_ms : this.item.source_duration_ms - 10000;
        this.loadTailPeaks();
      } else {
        this.endMs = this.item.source_duration_ms;
      }
    },

    // ---- playback -----------------------------------------------------------

    // One element for the panel, streaming the local file. Range requests mean
    // a seek fetches only the part about to play, not the whole surah.
    ensureAudio() {
      if (this.audio) return this.audio;
      const audio = new Audio(this.item.audio_url);
      audio.preload = "metadata";
      audio.onplay = () => {
        this.playing = true;
        this.tick();
      };
      audio.onpause = () => {
        this.playing = false;
      };
      audio.onended = () => {
        this.playing = false;
      };
      audio.onerror = () => {
        this.error = "Could not play the downloaded file.";
      };
      this.audio = audio;
      return audio;
    },

    tick() {
      cancelAnimationFrame(this.rafId);
      const step = () => {
        if (!this.audio) return;
        this.playheadMs = this.audio.currentTime * 1000;
        if (this.stopAt != null && this.audio.currentTime >= this.stopAt) {
          this.audio.pause();
          this.stopAt = null;
        }
        this.redraw();
        if (this.playing) this.rafId = requestAnimationFrame(step);
      };
      this.rafId = requestAnimationFrame(step);
    },

    seekTo(ms) {
      const audio = this.ensureAudio();
      this.playheadMs = ms;
      audio.currentTime = Math.max(0, ms) / 1000;
      this.redraw();
    },

    play(fromMs, untilMs) {
      const audio = this.ensureAudio();
      audio.currentTime = Math.max(0, fromMs) / 1000;
      this.playheadMs = Math.max(0, fromMs);
      this.stopAt = untilMs != null ? untilMs / 1000 : null;
      audio.play().catch((e) => {
        this.error = `Could not play: ${e.message}`;
      });
    },

    togglePlay() {
      const audio = this.ensureAudio();
      if (this.playing) {
        audio.pause();
      } else {
        this.stopAt = null;
        audio.play().catch((e) => {
          this.error = `Could not play: ${e.message}`;
        });
      }
    },

    stop() {
      cancelAnimationFrame(this.rafId);
      if (this.audio) {
        this.audio.pause();
        this.audio.currentTime = 0;
      }
      this.playing = false;
      this.stopAt = null;
      this.playheadMs = 0;
      this.redraw();
    },

    // ---- actions ------------------------------------------------------------

    async redetect() {
      this.busy = true;
      this.error = null;
      try {
        const updated = await this.api(this.detectUrl, { method: "POST" });
        this.$emit("updated", updated);
        this.startMs = updated.trim_start_ms || 0;
        this.endMs = updated.trim_end_ms || updated.source_duration_ms;
        this.$nextTick(this.redraw);
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    // For sources that publish surahs already stripped of the basmala: accept
    // the file whole rather than reviewing a cut that is not there.
    async approveWithoutTrim() {
      this.startMs = 0;
      this.endMs = this.item.source_duration_ms;
      this.redraw();
      await this.approve();
    },

    async approve() {
      this.busy = true;
      this.error = null;
      this.startedAt = Date.now();
      try {
        const body = new FormData();
        body.append("trim_start_ms", this.startMs);
        body.append("trim_end_ms", this.endMs);
        this.$emit("updated", await this.api(this.approveUrl, { method: "POST", body }));
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    }
  }
};
</script>

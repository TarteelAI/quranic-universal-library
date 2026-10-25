<template>
  <div class="compare-audio">
    <!-- Nothing to compare against until the surah has been exported once. -->
    <div v-if="!outputPath" class="border rounded p-4 text-sm text-gray-500">
      Export the repaired MP3 first — the comparison measures that file against the original.
    </div>

    <template v-else>
      <div class="border rounded p-3 mb-3">
        <div class="flex items-center gap-3 flex-wrap">
          <button class="btn btn-sm btn-dark" @click="start" :disabled="running">
            {{ running ? 'Measuring…' : (result ? 'Re-measure' : 'Compare with original') }}
          </button>

          <label class="flex items-center gap-2 text-xs text-gray-600">
            Sensitivity
            <input type="range" min="6" max="30" step="1" v-model.number="sensitivity" class="w-32" :disabled="running" />
            <span class="font-mono">{{ sensitivity }} dB above the codec floor</span>
          </label>

          <span v-if="running" class="text-xs text-gray-500">decoding both files end to end…</span>
          <span v-if="state.stale" class="text-xs text-amber-700">This measurement describes an earlier export. Re-measure.</span>
        </div>
        <p class="text-[11px] text-gray-400 mt-2">
          Re-encoding changes every sample a little, so "different" is measured against this file's own
          codec noise rather than against silence. Lower the sensitivity to see smaller differences,
          raise it to see only the obvious ones.
        </p>
        <p v-if="error" class="text-xs text-red-600 mt-1">{{ error }}</p>
      </div>

      <template v-if="result">
        <!-- The answer, in one line -->
        <div class="rounded p-3 mb-3 text-sm" :class="verdictClass">
          <strong>{{ verdict.title }}</strong>
          <span class="ml-1">{{ verdict.detail }}</span>
        </div>

        <!-- Whole surah at a glance: both waveforms, and what differs -->
        <div class="border rounded p-3 mb-3">
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-semibold text-sm">Whole surah</h3>
            <div class="flex items-center gap-3 text-[11px] text-gray-500">
              <span><i class="inline-block w-3 h-2 align-middle" style="background:#4f46e5"></i> asked for</span>
              <span><i class="inline-block w-3 h-2 align-middle" style="background:#dc2626"></i> not asked for</span>
              <span>{{ formatMs(result.duration_a_ms) }} · {{ result.chart.bucket_ms }} ms per pixel column</span>
            </div>
          </div>
          <canvas
            ref="overview"
            class="w-full block rounded border bg-white cursor-crosshair"
            style="height: 150px"
            @click="onOverviewClick"
          ></canvas>
          <p class="text-[11px] text-gray-400 mt-1">
            Original above the line, export below it. The strip underneath is how far each moment differs,
            relative to how loud it is; the dashed line is the threshold. Click anywhere to zoom.
          </p>
        </div>

        <!-- Findings -->
        <div class="border rounded p-3 mb-3">
          <h3 class="font-semibold text-sm mb-2">
            Differences found ({{ result.regions.length }})
          </h3>
          <p v-if="!result.regions.length" class="text-xs text-gray-400">
            The two files are identical to within the codec floor everywhere. That includes the repairs —
            at this sensitivity even they do not register, so lower it.
          </p>
          <table v-else class="w-full text-xs">
            <thead class="text-gray-400 text-left">
              <tr>
                <th class="py-1">At</th>
                <th>For</th>
                <th>Size</th>
                <th>Accounted for by</th>
                <th class="text-right">Listen</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(r, i) in result.regions"
                :key="i"
                class="border-t cursor-pointer"
                :class="zoomRegion === i ? 'bg-indigo-50' : 'hover:bg-gray-50'"
                @click="zoomTo(r, i)"
              >
                <td class="py-1 font-mono">{{ formatPrecise(r.start_ms) }}</td>
                <td class="font-mono text-gray-500">{{ Math.round(r.duration_ms) }} ms</td>
                <td class="font-mono" :class="r.expected ? 'text-gray-500' : 'text-red-600'">
                  {{ r.peak_rel_db }} dB
                </td>
                <td>
                  <span v-if="r.expected" class="inline-block px-1 rounded text-[10px] bg-indigo-100 text-indigo-700">repair</span>
                  <span v-else class="inline-block px-1 rounded text-[10px] bg-red-100 text-red-700">nothing</span>
                  <span class="ml-1 text-gray-600">{{ r.label || '—' }}</span>
                </td>
                <td class="text-right whitespace-nowrap">
                  <button class="btn btn-xs btn-outline-secondary" @click.stop="playRegion(r, 'a')">▶ original</button>
                  <button class="btn btn-xs btn-outline-secondary" @click.stop="playRegion(r, 'b')">▶ export</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Zoom: the same measurement at full detail -->
        <div v-if="zoom || zoomLoading" class="border rounded p-3 mb-3">
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-semibold text-sm">
              Close up — {{ formatPrecise(zoomStart) }} to {{ formatPrecise(zoomEnd) }}
            </h3>
            <button class="btn btn-xs btn-outline-secondary" @click="closeZoom">close</button>
          </div>
          <p v-if="zoomLoading" class="text-xs text-gray-400">measuring…</p>
          <canvas v-show="zoom" ref="detail" class="w-full block rounded border bg-white" style="height: 170px"></canvas>
          <p v-if="zoom" class="text-[11px] text-gray-400 mt-1">
            Original, export, and the difference between them at {{ zoom.hop_ms }} ms resolution.
            A difference track that is flat outside the shaded repair is what "nothing else changed" looks like.
          </p>
        </div>

        <!-- Did every repair actually land? -->
        <div class="border rounded p-3">
          <h3 class="font-semibold text-sm mb-2">Repairs in this export ({{ result.expected.length }})</h3>
          <p v-if="!result.expected.length" class="text-xs text-gray-400">No repairs recorded on this session.</p>
          <table v-else class="w-full text-xs">
            <tbody>
              <tr v-for="e in result.expected" :key="e.index" class="border-t">
                <td class="py-1 w-6 text-center">
                  <span v-if="e.detected" class="text-green-600">✓</span>
                  <span v-else class="text-red-600">✗</span>
                </td>
                <td class="font-mono text-gray-500">{{ formatPrecise(e.start_ms) }}</td>
                <td>{{ e.label }}</td>
                <td class="font-mono text-gray-500">{{ e.peak_rel_db }} dB</td>
                <td class="text-gray-500">
                  {{ e.detected ? 'changed the audio' : 'no change — this repair did not reach the export' }}
                </td>
              </tr>
            </tbody>
          </table>

          <dl class="grid grid-cols-2 md:grid-cols-4 gap-2 mt-3 pt-3 border-t text-[11px]">
            <div><dt class="text-gray-400">Codec floor</dt><dd class="font-mono">{{ result.baseline_rel_db }} dB</dd></div>
            <div><dt class="text-gray-400">Threshold</dt><dd class="font-mono">{{ result.threshold_rel_db }} dB</dd></div>
            <div><dt class="text-gray-400">Length change</dt><dd class="font-mono">{{ result.length_delta_ms }} ms</dd></div>
            <div><dt class="text-gray-400">Compared up to</dt><dd class="font-mono">{{ Math.round(result.analysis_rate / 2000) }} kHz</dd></div>
          </dl>
          <p v-if="shifted.length" class="text-[11px] text-amber-700 mt-2">
            Timing moved after {{ shifted.length }} point(s): {{ shifted.map(s => `${formatMs(s.start_ms)} by ${s.offset_ms} ms`).join(', ') }}.
            Everything downstream of a length-changing splice sits at a different time in the export.
          </p>
        </div>
      </template>

      <audio ref="playerA" class="hidden"></audio>
      <audio ref="playerB" class="hidden"></audio>
    </template>
  </div>
</template>

<script>
// Context either side of a finding, so it can be judged in place rather than
// as a disembodied 100 ms.
const LISTEN_PAD_MS = 700;
const ZOOM_PAD_MS = 400;

export default {
  props: {
    sessionId: { type: String, required: true },
    outputPath: { default: null }
  },

  data() {
    return {
      state: {},
      error: null,
      running: false,
      sensitivity: 18,
      pollTimer: null,
      stopTimer: null,
      zoom: null,
      zoomLoading: false,
      zoomRegion: null,
      zoomStart: 0,
      zoomEnd: 0
    };
  },

  computed: {
    base() {
      return `/audio_repair/sessions/${this.sessionId}`;
    },
    result() {
      return this.state.status === "ready" ? this.state.result : null;
    },
    shifted() {
      return (this.result?.segments || []).filter((s) => Math.abs(s.offset_ms) >= 1);
    },
    verdict() {
      const r = this.result;
      const unexpected = r.unexpected.length;
      const missed = r.undetected.length;

      if (unexpected) {
        return {
          tone: "bad",
          title: `${unexpected} change${unexpected > 1 ? "s" : ""} no repair accounts for.`,
          detail: "Listen to the rows marked “nothing” below before shipping this export."
        };
      }
      if (missed) {
        return {
          tone: "warn",
          title: `Nothing unintended, but ${missed} repair${missed > 1 ? "s" : ""} left no trace.`,
          detail: "The export does not contain the change you applied."
        };
      }
      // A length change is not a "difference" the residual can see — it moves
      // every timing downstream, which matters more than most of what it can.
      if (Math.abs(r.length_delta_ms) >= 1) {
        return {
          tone: "warn",
          title: `Nothing unintended, but the export is ${r.length_delta_ms} ms ${r.length_delta_ms > 0 ? "longer" : "shorter"}.`,
          detail: "Segment timings after the first length-changing splice no longer line up with this recitation's stored timings."
        };
      }
      return {
        tone: "good",
        title: "Clean.",
        detail: `The export differs from the original only inside the ${r.expected.length} repaired region${r.expected.length === 1 ? "" : "s"}; everywhere else the two files agree to within re-encoding noise.`
      };
    },
    verdictClass() {
      return {
        good: "bg-green-50 text-green-900 border border-green-200",
        warn: "bg-amber-50 text-amber-900 border border-amber-200",
        bad: "bg-red-50 text-red-900 border border-red-200"
      }[this.verdict.tone];
    }
  },

  mounted() {
    this.load();
    window.addEventListener("resize", this.redraw);
  },

  beforeUnmount() {
    window.removeEventListener("resize", this.redraw);
    this.clearTimers();
  },

  methods: {
    clearTimers() {
      if (this.pollTimer) clearInterval(this.pollTimer);
      if (this.stopTimer) clearTimeout(this.stopTimer);
      this.pollTimer = null;
      this.stopTimer = null;
    },

    async api(url, { method = "GET" } = {}) {
      const opts = { method, headers: { Accept: "application/json" } };
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
        this.apply(await this.api(`${this.base}/comparison`));
      } catch (e) {
        this.error = e.message;
      }
    },

    apply(state) {
      this.state = state || {};
      this.running = state && state.status === "running";
      if (state && state.status === "failed") this.error = state.error;
      if (this.running) this.poll();
      if (this.result) this.$nextTick(this.drawOverview);
    },

    async start() {
      this.error = null;
      this.zoom = null;
      this.zoomRegion = null;
      try {
        const q = new URLSearchParams({ sensitivity_db: this.sensitivity });
        this.apply(await this.api(`${this.base}/compare?${q}`, { method: "POST" }));
      } catch (e) {
        this.error = e.message;
        this.running = false;
      }
    },

    poll() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(async () => {
        try {
          const s = await this.api(`${this.base}/comparison`);
          if (s.status !== "running") {
            clearInterval(this.pollTimer);
            this.pollTimer = null;
            this.apply(s);
          }
        } catch (e) {
          clearInterval(this.pollTimer);
          this.pollTimer = null;
          this.running = false;
          this.error = e.message;
        }
      }, 2000);
    },

    redraw() {
      if (this.result) this.drawOverview();
      if (this.zoom) this.drawDetail();
    },

    // ---- drawing ----------------------------------------------------------

    fit(canvas) {
      const dpr = window.devicePixelRatio || 1;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      return { ctx, w, h };
    },

    drawOverview() {
      const canvas = this.$refs.overview;
      if (!canvas || !this.result) return;
      const { ctx, w, h } = this.fit(canvas);

      const r = this.result;
      const chart = r.chart;
      const total = r.duration_a_ms || 1;
      const x = (ms) => (ms / total) * w;

      const waveH = h - 44;              // waveform pane
      const mid = waveH / 2;
      const diffTop = waveH + 8;
      const diffH = h - diffTop - 2;

      // Changed regions sit behind the waveforms, so a finding reads as a
      // column through both of them rather than as a separate legend.
      // A 100 ms finding in a 17-minute file is a fraction of a pixel wide, so
      // each one gets a minimum width and a flag at the top edge. Without those
      // the thing the whole panel exists to show is invisible.
      r.regions.forEach((region) => {
        const centre = x((region.start_ms + region.end_ms) / 2);
        const width = Math.max(3, x(region.end_ms) - x(region.start_ms));
        const x0 = centre - width / 2;
        const colour = region.expected ? "#4f46e5" : "#dc2626";

        ctx.globalAlpha = region.expected ? 0.16 : 0.2;
        ctx.fillStyle = colour;
        ctx.fillRect(x0, 6, width, h - 6);
        ctx.globalAlpha = 1;

        ctx.fillStyle = colour;
        ctx.beginPath();
        ctx.moveTo(centre - 4, 0);
        ctx.lineTo(centre + 4, 0);
        ctx.lineTo(centre, 7);
        ctx.closePath();
        ctx.fill();
      });

      const n = chart.a.length;
      const bw = w / n;
      const scale = Math.max(...chart.a, ...chart.b, 0.05);

      ctx.fillStyle = "rgba(55,65,81,0.70)";
      for (let i = 0; i < n; i++) {
        const v = (chart.a[i] / scale) * (mid - 1);
        ctx.fillRect(i * bw, mid - v, Math.max(0.6, bw), v);
      }
      ctx.fillStyle = "rgba(37,99,235,0.70)";
      for (let i = 0; i < n; i++) {
        const v = (chart.b[i] / scale) * (mid - 1);
        ctx.fillRect(i * bw, mid, Math.max(0.6, bw), v);
      }

      ctx.strokeStyle = "#d1d5db";
      ctx.beginPath();
      ctx.moveTo(0, mid);
      ctx.lineTo(w, mid);
      ctx.stroke();

      // Difference strip. The floor of the scale is the codec baseline, so the
      // bar is zero where the two files only disagree about re-encoding.
      const floor = r.baseline_rel_db;
      const ceil = 0;
      const norm = (db) => Math.max(0, Math.min(1, (db - floor) / (ceil - floor)));

      ctx.fillStyle = "#f3f4f6";
      ctx.fillRect(0, diffTop, w, diffH);
      for (let i = 0; i < n; i++) {
        const v = norm(chart.rel_db[i]) * diffH;
        const over = chart.rel_db[i] > r.threshold_rel_db;
        ctx.fillStyle = over ? "#dc2626" : "rgba(107,114,128,0.55)";
        ctx.fillRect(i * bw, diffTop + diffH - v, Math.max(0.6, bw), v);
      }

      ctx.save();
      ctx.setLineDash([4, 3]);
      ctx.strokeStyle = "#9ca3af";
      const ty = diffTop + diffH - norm(r.threshold_rel_db) * diffH;
      ctx.beginPath();
      ctx.moveTo(0, ty);
      ctx.lineTo(w, ty);
      ctx.stroke();
      ctx.restore();

      ctx.fillStyle = "#6b7280";
      ctx.font = "10px ui-monospace, monospace";
      ctx.fillText("difference", 4, diffTop + 10);
    },

    drawDetail() {
      const canvas = this.$refs.detail;
      if (!canvas || !this.zoom) return;
      const { ctx, w, h } = this.fit(canvas);

      const z = this.zoom;
      const n = z.a.length;
      const bw = w / n;
      const lane = h / 3;
      const scale = Math.max(...z.a, ...z.b, 0.02);

      // The repair's own span, so "the difference stops here" is visible rather
      // than inferred.
      if (this.zoomRegion != null) {
        const region = this.result.regions[this.zoomRegion];
        const x0 = ((region.start_ms - z.start_ms) / (z.end_ms - z.start_ms)) * w;
        const x1 = ((region.end_ms - z.start_ms) / (z.end_ms - z.start_ms)) * w;
        ctx.fillStyle = region.expected ? "rgba(79,70,229,0.10)" : "rgba(220,38,38,0.10)";
        ctx.fillRect(x0, 0, x1 - x0, h);
      }

      // The difference is by nature far quieter than the audio it is a
      // difference between; drawn at the same scale a real finding can look like
      // a flat line. It gets its own gain, stated rather than hidden.
      const peak = Math.max(...z.d, 1e-6);
      const gain = Math.min(200, Math.max(1, scale / peak));

      const lanes = [
        { values: z.a, colour: "rgba(55,65,81,0.8)", label: "original", scale },
        { values: z.b, colour: "rgba(37,99,235,0.8)", label: "export", scale },
        { values: z.d, colour: "#dc2626", scale: scale / gain,
          label: `difference${gain > 1.5 ? ` ×${Math.round(gain)}` : ""}` }
      ];

      lanes.forEach((row, index) => {
        const mid = lane * index + lane / 2;
        ctx.strokeStyle = "#e5e7eb";
        ctx.beginPath();
        ctx.moveTo(0, mid);
        ctx.lineTo(w, mid);
        ctx.stroke();

        ctx.fillStyle = row.colour;
        for (let i = 0; i < n; i++) {
          const v = (row.values[i] / row.scale) * (lane / 2 - 2);
          ctx.fillRect(i * bw, mid - v, Math.max(0.6, bw), v * 2 || 0.5);
        }

        ctx.fillStyle = "#6b7280";
        ctx.font = "10px ui-monospace, monospace";
        ctx.fillText(row.label, 4, lane * index + 11);
      });
    },

    // ---- zoom & playback --------------------------------------------------

    onOverviewClick(event) {
      const rect = event.currentTarget.getBoundingClientRect();
      const at = ((event.clientX - rect.left) / rect.width) * this.result.duration_a_ms;
      const near = this.result.regions.findIndex((r) => at >= r.start_ms - 500 && at <= r.end_ms + 500);
      if (near >= 0) {
        this.zoomTo(this.result.regions[near], near);
      } else {
        this.fetchZoom(at - 750, at + 750, null);
      }
    },

    zoomTo(region, index) {
      this.fetchZoom(region.start_ms - ZOOM_PAD_MS, region.end_ms + ZOOM_PAD_MS, index);
    },

    async fetchZoom(startMs, endMs, regionIndex) {
      this.zoomLoading = true;
      this.zoomRegion = regionIndex;
      this.zoomStart = Math.max(0, startMs);
      this.zoomEnd = endMs;
      try {
        const q = new URLSearchParams({
          start_ms: Math.max(0, Math.round(startMs)),
          end_ms: Math.round(endMs),
          threshold_rel_db: this.result.threshold_rel_db
        });
        this.zoom = await this.api(`${this.base}/comparison_zoom?${q}`);
        this.$nextTick(this.drawDetail);
      } catch (e) {
        this.error = e.message;
        this.zoom = null;
      } finally {
        this.zoomLoading = false;
      }
    },

    closeZoom() {
      this.zoom = null;
      this.zoomRegion = null;
    },

    // Both players are seeked into the full file rather than cutting clips —
    // the two files are already served, and a finding is only ever a second long.
    playRegion(region, which) {
      const player = which === "a" ? this.$refs.playerA : this.$refs.playerB;
      const other = which === "a" ? this.$refs.playerB : this.$refs.playerA;
      const url = which === "a" ? this.state.original_url : this.state.repaired_url;
      if (!player || !url) return;

      other?.pause();
      if (this.stopTimer) clearTimeout(this.stopTimer);

      // The export's own timeline, if a splice moved this part of it.
      const shift = which === "b" ? this.shiftAt(region.start_ms) : 0;
      const from = Math.max(0, region.start_ms + shift - LISTEN_PAD_MS);
      const span = region.duration_ms + LISTEN_PAD_MS * 2;

      if (player.getAttribute("src") !== url) player.setAttribute("src", url);
      player.currentTime = from / 1000;
      player.play();
      this.stopTimer = setTimeout(() => player.pause(), span);
    },

    shiftAt(ms) {
      const segments = this.result?.segments || [];
      const seg = [...segments].reverse().find((s) => s.start_ms <= ms);
      return seg ? seg.offset_ms : 0;
    },

    // Findings are tens of milliseconds long; m:ss cannot describe one.
    formatPrecise(ms) {
      const total = Math.max(0, ms) / 1000;
      const m = Math.floor(total / 60);
      return `${m}:${(total - m * 60).toFixed(2).padStart(5, "0")}`;
    },

    formatMs(ms) {
      const total = Math.max(0, Math.round(ms / 1000));
      const m = Math.floor(total / 60);
      const s = total % 60;
      return `${m}:${String(s).padStart(2, "0")}`;
    }
  }
};
</script>

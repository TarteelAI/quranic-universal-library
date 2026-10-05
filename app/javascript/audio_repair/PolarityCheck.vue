<template>
  <div class="polarity-check">
    <!-- What this is for, in one line -->
    <p class="text-sm text-gray-600 mb-3">
      Some published files have the right channel inverted. Headphones play them normally; a phone earpiece,
      a mono speaker, or any app that sums to mono hears the recitation drop out. Drop in the file as published
      and, if you have one, the corrected version — this finds every inverted stretch, lets you hear the
      cancellation here in the browser, and checks that the fix is complete and changed nothing else.
    </p>

    <!-- Inputs -->
    <div v-if="showForm" class="border rounded p-3 mb-3">
      <div class="grid md:grid-cols-2 gap-3">
        <div
          v-for="kind in ['original', 'fixed']"
          :key="kind"
          class="border-2 border-dashed rounded p-3 transition"
          :class="drag[kind] ? 'border-indigo-400 bg-indigo-50' : 'border-gray-300'"
          @dragover.prevent="drag[kind] = true"
          @dragleave.prevent="drag[kind] = false"
          @drop.prevent="onDrop($event, kind)"
        >
          <div class="flex items-baseline justify-between mb-1">
            <span class="font-semibold text-sm">{{ kind === 'original' ? 'Original' : 'Fixed' }}</span>
            <span class="text-[11px] text-gray-400">
              {{ kind === 'original' ? 'the file as published' : 'optional — the corrected file to validate' }}
            </span>
          </div>

          <div v-if="files[kind]" class="flex items-center justify-between text-xs bg-white border rounded px-2 py-1">
            <span class="truncate">📄 {{ files[kind].name }} <span class="text-gray-400">· {{ (files[kind].size / 1048576).toFixed(1) }} MB</span></span>
            <button class="text-gray-400 hover:text-red-600 ml-2" title="remove" @click="files[kind] = null">✕</button>
          </div>
          <p v-else class="text-xs text-gray-500">
            Drop an mp3 here,
            <label class="underline cursor-pointer text-indigo-700">
              choose a file<input type="file" accept="audio/*,.mp3" class="hidden" @change="onPick($event, kind)" />
            </label>,
            or paste a URL:
          </p>
          <input
            v-if="!files[kind]"
            v-model.trim="urls[kind]"
            type="url"
            class="form-control form-control-sm mt-1"
            :placeholder="kind === 'original' ? 'https://audio-cdn.tarteel.ai/quran/surah/…/092.mp3' : 'https://…/092.mp3'"
          />
        </div>
      </div>

      <div class="flex items-end gap-3 flex-wrap mt-3">
        <label class="text-xs text-gray-600">
          Recitation <span class="text-gray-400">(labels windows with ayah numbers)</span>
          <select v-model="recitationId" class="form-control form-control-sm w-72 block">
            <option :value="null">—</option>
            <option v-for="r in recitations" :key="r.id" :value="r.id">{{ r.id }} · {{ r.name }}</option>
          </select>
        </label>
        <label class="text-xs text-gray-600">
          Surah
          <input v-model.number="chapterId" type="number" min="1" max="114" class="form-control form-control-sm w-20 block" />
        </label>
        <label class="text-xs text-gray-600 flex-1 min-w-[160px]">
          Label <span class="text-gray-400">(optional)</span>
          <input v-model.trim="label" type="text" class="form-control form-control-sm block w-full" placeholder="e.g. Maher 092 after flip" />
        </label>
        <button class="btn btn-sm btn-dark" :disabled="submitting || !canSubmit" @click="submit">
          {{ submitting ? 'Uploading…' : 'Analyse' }}
        </button>
        <button v-if="check" class="btn btn-sm btn-outline-secondary" @click="showForm = false">cancel</button>
      </div>
      <p class="text-[11px] text-gray-400 mt-2">
        No original but a recitation and surah picked? The published file for that surah is checked.
      </p>
      <p v-if="error" class="text-xs text-red-600 mt-1">{{ error }}</p>
    </div>

    <!-- Progress / failure -->
    <div v-if="check && (check.status === 'queued' || check.status === 'running')" class="border rounded p-3 mb-3 text-sm">
      <span class="inline-block w-3 h-3 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin align-middle mr-2"></span>
      {{ check.status === 'queued' ? 'Queued…' : 'Scanning…' }}
      <span class="text-xs text-gray-500">
        {{ check.inputs.original.source === 'url' ? 'downloading and ' : '' }}decoding the whole file; a long surah takes up to a minute.
      </span>
    </div>
    <div v-if="check && check.status === 'failed'" class="rounded p-3 mb-3 text-sm bg-red-50 text-red-900 border border-red-200">
      <strong>Analysis failed.</strong> {{ check.error }}
    </div>

    <!-- Results -->
    <template v-if="result">
      <div class="flex items-center justify-between mb-2">
        <div class="text-sm">
          <strong>{{ check.label }}</strong>
          <span v-if="check.recitation" class="text-gray-500"> · {{ check.recitation.name }}</span>
          <span v-if="check.chapter" class="text-gray-500"> · surah {{ check.chapter.id }} {{ check.chapter.name }}</span>
          <span class="ml-1" :class="pillClass(original.status)">{{ statusLabel(original.status) }}</span>
          <span v-if="verdict" class="ml-1" :class="pillClass(verdict.status)">fix {{ verdict.status }}</span>
        </div>
        <div class="flex gap-2">
          <a v-if="result.fixed_url" :href="result.fixed_url" download class="btn btn-sm btn-outline-secondary">⬇ fixed file</a>
          <button class="btn btn-sm btn-outline-secondary" @click="newCheck">New check</button>
        </div>
      </div>

      <!-- The answer, in one line -->
      <div class="rounded p-3 mb-3 text-sm" :class="summaryClass">
        <strong>{{ summary.title }}</strong>
        <span class="ml-1">{{ summary.detail }}</span>
      </div>

      <!-- Listen -->
      <div class="border rounded p-3 mb-3">
        <div class="flex items-center gap-3 flex-wrap">
          <div class="inline-flex border border-gray-300 rounded-md overflow-hidden">
            <button :class="segClass(source === 'original')" @click="setSource('original')">Original</button>
            <button :class="segClass(source === 'fixed')" :disabled="!result.fixed_url" @click="setSource('fixed')">Fixed</button>
          </div>
          <div class="inline-flex border border-gray-300 rounded-md overflow-hidden" title="How the output is mixed. Mono is (L+R)/2 — exactly what a phone earpiece or a mono speaker does.">
            <button v-for="m in modes" :key="m.id" :class="segClass(mode === m.id)" @click="setMode(m.id)">{{ m.label }}</button>
          </div>
          <button class="btn btn-sm btn-dark" @click="togglePlay">{{ playing ? 'Pause' : 'Play' }}</button>
          <span class="font-mono text-xs w-28">{{ formatSec(currentTime) }} / {{ formatSec(duration) }}</span>
          <div class="relative w-44 h-3.5 bg-gray-200 rounded overflow-hidden" title="output level, loudest channel">
            <i class="absolute inset-y-0 left-0" :style="{ width: meter.pct + '%', background: meter.db < -40 ? '#dc2626' : '#16a34a' }"></i>
            <span class="absolute right-1.5 -top-px text-[11px] font-mono">{{ meter.db <= -99 ? '-inf' : meter.db.toFixed(0) }} dB</span>
          </div>
        </div>
        <p class="text-[11px] text-gray-400 mt-2">
          Switch to <b>Mono (L+R)</b> and play an inverted window: the meter collapses and the recitation drops out.
          Switch the source to <b>Fixed</b> at the same spot to hear the repair. Click a timeline to seek both files.
          Space plays and pauses.
        </p>
      </div>

      <!-- Timelines -->
      <div class="border rounded p-3 mb-3">
        <!-- One zoom for both lanes, so original and fixed always show the same stretch -->
        <div class="flex items-center justify-between flex-wrap gap-2 mb-2">
          <div class="flex items-center gap-1 text-xs">
            <button class="btn btn-xs btn-outline-secondary" title="zoom out" @click="zoomBy(2)">−</button>
            <button class="btn btn-xs btn-outline-secondary" title="zoom in" @click="zoomBy(0.5)">+</button>
            <button class="btn btn-xs btn-outline-secondary" :disabled="!view" @click="fitView">whole file</button>
            <button class="btn btn-xs btn-outline-secondary" :disabled="!original.windows.length" @click="zoomToWindows">all windows</button>
            <span class="font-mono text-gray-500 ml-2">{{ formatSec(viewRange.start) }} – {{ formatSec(viewRange.end) }}</span>
            <span v-if="view" class="text-gray-400">· {{ zoomFactor }}×</span>
          </div>
          <span class="text-[11px] text-gray-400">ctrl/⌘ + wheel zooms at the cursor · drag to pan · click to seek</span>
        </div>
        <div v-for="key in lanes" :key="key" class="mb-2">
          <div class="flex justify-between text-[11px] text-gray-500 mb-1">
            <span>{{ key === 'original' ? 'Original' : 'Fixed' }} <span class="text-gray-400">· {{ fileMeta(result[key]) }}</span></span>
            <span>{{ laneSummary(result[key]) }}</span>
          </div>
          <canvas :ref="'tl_' + key" class="w-full block rounded border bg-white select-none" style="height: 64px"
                  :class="drag.panning ? 'cursor-grabbing' : 'cursor-crosshair'"
                  @mousedown.prevent="onTimelineDown($event, key)"
                  @mousemove="onTimelineMove($event, key)"
                  @mouseup="onTimelineUp($event, key)"
                  @mouseleave="onTimelineLeave"
                  @wheel="onTimelineWheel($event, key)"></canvas>
        </div>
        <div class="flex gap-4 flex-wrap text-[11px] text-gray-500">
          <span><i class="inline-block w-3 h-2 align-middle mr-1 rounded-sm" style="background:#16a34a"></i>in phase (mono sums)</span>
          <span><i class="inline-block w-3 h-2 align-middle mr-1 rounded-sm" style="background:#dc2626"></i>inverted (mono cancels)</span>
          <span><i class="inline-block w-3 h-2 align-middle mr-1 rounded-sm" style="background:#d1d5db"></i>silence</span>
          <span><i class="inline-block w-3 h-2 align-middle mr-1 rounded-sm" style="background:rgba(220,38,38,.25); border:1px solid #dc2626"></i>flagged window</span>
          <span><i class="inline-block w-3 h-2 align-middle mr-1 rounded-sm" style="background:#c7d2fe"></i>ayah boundary</span>
        </div>
      </div>

      <!-- Windows -->
      <div class="border rounded p-3 mb-3">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-semibold text-sm">Inverted windows ({{ original.windows.length }})</h3>
          <button
            v-if="original.windows.length"
            class="btn btn-sm btn-primary"
            :disabled="fixing"
            @click="generateFix"
          >
            {{ fixing ? 'Building…' : (result.fixed ? 'Rebuild fixed file from these windows' : 'Generate fixed file') }}
          </button>
        </div>
        <p v-if="!original.windows.length" class="text-xs text-gray-400">
          None. The mono mix carries the full signal everywhere.
        </p>
        <table v-else class="w-full text-xs">
          <thead class="text-gray-400 text-left">
            <tr>
              <th class="py-1">From</th><th>To</th><th>Length</th><th>Ayah</th>
              <th>Stereo</th><th>Mono mix</th><th>Loss</th>
              <th v-if="result.fixed">After fix</th>
              <th class="text-right">Listen</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(w, i) in original.windows" :key="i" class="border-t">
              <td class="py-1 font-mono">{{ formatSec(w.from) }}</td>
              <td class="font-mono">{{ formatSec(w.to) }}</td>
              <td class="font-mono">{{ w.duration.toFixed(1) }}s</td>
              <td>
                <span v-if="w.ayahs.length">{{ w.ayahs.join(', ') }}</span>
                <span v-else-if="w.after_last_ayah" class="text-gray-400">after last ayah</span>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="font-mono">{{ db(w.stereo_rms) }}</td>
              <td class="font-mono">{{ db(w.mono_rms) }}</td>
              <td class="font-mono" :class="w.mono_loss_db > 6 ? 'text-red-600' : ''">{{ db(w.mono_loss_db) }}</td>
              <td v-if="result.fixed" class="font-mono" :class="checkedLoss(i) != null && Math.abs(checkedLoss(i)) < 3 ? 'text-green-600' : 'text-red-600'">
                {{ db(checkedLoss(i)) }}
              </td>
              <td class="text-right whitespace-nowrap">
                <button class="btn btn-xs btn-outline-secondary" title="zoom both timelines to this window" @click="zoomTo(w.from - 2, w.to + 2)">🔍</button>
                <button class="btn btn-xs btn-outline-secondary" @click="playWindow('original', w)">▶ original</button>
                <button v-if="result.fixed_url" class="btn btn-xs btn-outline-secondary" @click="playWindow('fixed', w)">▶ fixed</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="original.windows.length" class="text-[11px] text-gray-400 mt-2">
          Playback starts 1.5 s before the window and stops 1.5 s after it, in Mono so the drop-out is audible.
          "Generate fixed file" flips the right channel inside these windows (the whole file when all of it is inverted),
          keeps the tags, bitrate and sample rate, and validates the result.
        </p>
      </div>

      <!-- Verdict -->
      <div v-if="verdict" class="border rounded p-3 mb-3">
        <h3 class="font-semibold text-sm mb-2">
          Fix validation
          <span class="ml-1" :class="pillClass(verdict.status)">{{ verdict.status }}</span>
          <span class="text-[11px] text-gray-400 font-normal ml-1">{{ check.inputs.fixed.source === 'generated' ? 'generated here' : check.inputs.fixed.name }}</span>
        </h3>
        <ul class="text-xs space-y-1">
          <li v-for="(c, i) in verdict.checks" :key="i" :class="c.ok ? 'text-green-700' : 'text-red-700'">
            {{ c.ok ? '✓' : '✗' }} {{ c.label }} <span class="text-gray-400">{{ c.detail }}</span>
          </li>
        </ul>
      </div>

      <audio ref="player_original" crossorigin="anonymous" preload="metadata" class="hidden"></audio>
      <audio ref="player_fixed" crossorigin="anonymous" preload="metadata" class="hidden"></audio>
    </template>

    <!-- Recent -->
    <div v-if="recentChecks.length" class="border rounded p-3">
      <h3 class="font-semibold text-sm mb-2">Recent checks</h3>
      <table class="w-full text-xs">
        <thead class="text-gray-400 text-left"><tr><th class="py-1">Label</th><th>When</th><th>Original</th><th>Mono loss</th><th>Fix</th></tr></thead>
        <tbody>
          <tr v-for="r in recentChecks" :key="r.id" class="border-t cursor-pointer hover:bg-gray-50" :class="check && check.id === r.id ? 'bg-indigo-50' : ''" @click="load(r.id)">
            <td class="py-1">{{ r.label }} <span v-if="r.chapter" class="text-gray-400">· surah {{ r.chapter.id }}</span></td>
            <td class="text-gray-500">{{ new Date(r.created_at).toLocaleString() }}</td>
            <td><span v-if="r.summary" :class="pillClass(r.summary.original_status)">{{ statusLabel(r.summary.original_status) }}</span><span v-else class="text-gray-400">{{ r.status }}</span></td>
            <td class="font-mono">{{ r.summary && r.summary.mono_loss_db != null ? r.summary.mono_loss_db.toFixed(1) + ' dB' : '' }}</td>
            <td><span v-if="r.summary && r.summary.verdict" :class="pillClass(r.summary.verdict)">{{ r.summary.verdict }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script>
const LISTEN_PAD_S = 1.5;

// Output matrix per mode: [L→left, L→right, R→left, R→right].
// Mono is every path at 0.5, i.e. (L+R)/2 on both ears — the same sum a mono device makes.
const MODES = {
  stereo: [1, 0, 0, 1],
  mono: [0.5, 0.5, 0.5, 0.5],
  left: [1, 1, 0, 0],
  right: [0, 0, 1, 1]
};

export default {
  props: {
    recitations: { type: Array, default: () => [] },
    recent: { type: Array, default: () => [] },
    initialId: { default: null }
  },

  data() {
    return {
      files: { original: null, fixed: null },
      urls: { original: "", fixed: "" },
      recitationId: null,
      chapterId: null,
      label: "",
      submitting: false,
      fixing: false,
      error: null,
      showForm: true,
      check: null,
      recentChecks: this.recent,
      pollTimer: null,
      modes: [
        { id: "stereo", label: "Stereo" },
        { id: "mono", label: "Mono (L+R)" },
        { id: "left", label: "Left" },
        { id: "right", label: "Right" }
      ],
      source: "original",
      mode: "stereo",
      playing: false,
      currentTime: 0,
      duration: 0,
      stopAt: null,
      view: null,                 // { start, end } in seconds; null = whole file
      drag: { original: false, fixed: false, panning: false, x: 0, start: 0, moved: false },
      meter: { db: -100, pct: 0 }
    };
  },

  computed: {
    base() {
      return "/audio_repair/polarity";
    },
    result() {
      return this.check && this.check.status === "ready" ? this.check.result : null;
    },
    original() {
      return this.result?.original;
    },
    verdict() {
      return this.result?.verdict;
    },
    lanes() {
      return this.result?.fixed ? ["original", "fixed"] : ["original"];
    },
    viewRange() {
      if (this.view) return this.view;
      return { start: 0, end: this.result ? Math.max(...this.lanes.map((k) => this.result[k]?.duration || 0), 1) : 1 };
    },
    zoomFactor() {
      if (!this.view || !this.result) return 1;
      const total = Math.max(...this.lanes.map((k) => this.result[k]?.duration || 0), 1);
      const f = total / (this.view.end - this.view.start);
      return f >= 10 ? Math.round(f) : f.toFixed(1);
    },
    canSubmit() {
      return !!(this.files.original || this.urls.original || (this.recitationId && this.chapterId));
    },
    summary() {
      const o = this.original;
      const v = this.verdict;
      if (o.status === "mono") {
        return { tone: "good", title: "Mono file.", detail: "One channel, so polarity cannot cancel anything." };
      }
      if (v) {
        if (v.status === "pass") {
          return {
            tone: "good",
            title: "Fix passes.",
            detail: `No inverted audio remains, the mono mix is as loud as stereo, and duration, sample rate and tags are unchanged.`
          };
        }
        const failed = v.checks.filter((c) => !c.ok).length;
        return { tone: "bad", title: `Fix fails ${failed} check${failed > 1 ? "s" : ""}.`, detail: "See the validation list below." };
      }
      if (o.status === "inverted") {
        return {
          tone: "bad",
          title: "Whole file inverted.",
          detail: `The right channel is the negative of the left (correlation ${o.phase_mean}). Mono playback loses ${o.mono_loss_db} dB — effectively silent.`
        };
      }
      if (o.status === "partial") {
        const secs = o.inverted_secs;
        return {
          tone: "warn",
          title: `${o.windows.length} inverted window${o.windows.length > 1 ? "s" : ""}, ${secs}s in total.`,
          detail: "Those stretches drop out on mono playback; the rest of the file is fine. Listed below with ayah numbers."
        };
      }
      return { tone: "good", title: "Clean.", detail: `Both channels are in phase throughout (correlation ${o.phase_mean}); the mono mix loses ${o.mono_loss_db} dB.` };
    },
    summaryClass() {
      return {
        good: "bg-green-50 text-green-900 border border-green-200",
        warn: "bg-amber-50 text-amber-900 border border-amber-200",
        bad: "bg-red-50 text-red-900 border border-red-200"
      }[this.summary.tone];
    }
  },

  created() {
    // Audio nodes must not become reactive proxies.
    this.audio = { ctx: null, merger: null, analysers: null, players: {} };
  },

  mounted() {
    window.addEventListener("resize", this.draw);
    window.addEventListener("keydown", this.onKey);
    if (this.initialId) this.load(this.initialId);
  },

  beforeUnmount() {
    window.removeEventListener("resize", this.draw);
    window.removeEventListener("keydown", this.onKey);
    this.stopPolling();
    this.pause();
  },

  methods: {
    // ---- inputs ------------------------------------------------------------

    onDrop(event, kind) {
      this.drag[kind] = false;
      const file = [...(event.dataTransfer.files || [])][0];
      if (file) this.files[kind] = file;
      const text = event.dataTransfer.getData("text/uri-list") || event.dataTransfer.getData("text/plain");
      if (!file && text && /^https?:\/\//.test(text.trim())) this.urls[kind] = text.trim();
    },

    onPick(event, kind) {
      const file = event.target.files[0];
      if (file) this.files[kind] = file;
      event.target.value = "";
    },

    async submit() {
      this.error = null;
      this.submitting = true;
      try {
        const form = new FormData();
        if (this.files.original) form.append("original_file", this.files.original);
        else if (this.urls.original) form.append("original_url", this.urls.original);
        if (this.files.fixed) form.append("fixed_file", this.files.fixed);
        else if (this.urls.fixed) form.append("fixed_url", this.urls.fixed);
        if (this.recitationId) form.append("recitation_id", this.recitationId);
        if (this.chapterId) form.append("chapter_id", this.chapterId);
        if (this.label) form.append("label", this.label);

        const state = await this.api(this.base, { method: "POST", body: form });
        this.files = { original: null, fixed: null };
        this.urls = { original: "", fixed: "" };
        this.apply(state);
      } catch (e) {
        this.error = e.message;
      } finally {
        this.submitting = false;
      }
    },

    async generateFix() {
      this.fixing = true;
      this.error = null;
      try {
        this.apply(await this.api(`${this.base}/${this.check.id}/fix`, { method: "POST" }));
      } catch (e) {
        this.error = e.message;
      } finally {
        this.fixing = false;
      }
    },

    newCheck() {
      this.pause();
      this.showForm = true;
      this.check = null;
      history.replaceState(null, "", location.pathname);
    },

    // ---- state -------------------------------------------------------------

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

    async load(id) {
      this.error = null;
      try {
        this.apply(await this.api(`${this.base}/${id}`));
      } catch (e) {
        this.error = e.message;
      }
    },

    apply(state) {
      const changed = !this.check || this.check.id !== state.id;
      if (changed) this.pause();
      this.check = state;
      this.showForm = false;
      history.replaceState(null, "", `${location.pathname}?id=${state.id}`);

      if (state.status === "queued" || state.status === "running") {
        this.poll();
      } else {
        this.stopPolling();
        this.refreshRecent();
      }
      if (this.result) {
        if (changed) { this.source = "original"; this.view = null; }
        this.$nextTick(() => {
          this.wirePlayers();
          this.draw();
        });
      }
    },

    poll() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(async () => {
        try {
          const s = await this.api(`${this.base}/${this.check.id}`);
          if (s.status !== "queued" && s.status !== "running") {
            this.stopPolling();
            this.apply(s);
          } else if (s.status !== this.check.status) {
            this.check = s; // queued -> running
          }
        } catch (e) {
          this.stopPolling();
          this.error = e.message;
        }
      }, 2000);
    },

    stopPolling() {
      if (this.pollTimer) clearInterval(this.pollTimer);
      this.pollTimer = null;
    },

    refreshRecent() {
      if (!this.check) return;
      const row = {
        id: this.check.id,
        status: this.check.status,
        label: this.check.label,
        created_at: this.check.created_at,
        recitation: this.check.recitation,
        chapter: this.check.chapter,
        summary: this.result && {
          original_status: this.original.status,
          mono_loss_db: this.original.mono_loss_db,
          windows: this.original.windows.length,
          verdict: this.verdict?.status
        }
      };
      this.recentChecks = [row, ...this.recentChecks.filter((r) => r.id !== row.id)].slice(0, 20);
    },

    // ---- audio graph -------------------------------------------------------
    // element -> splitter -> 4 gains -> merger -> speakers, plus an analyser per
    // output channel for the meter.

    ensureGraph() {
      const a = this.audio;
      if (a.ctx) return;
      a.ctx = new (window.AudioContext || window.webkitAudioContext)();
      a.merger = a.ctx.createChannelMerger(2);
      a.merger.connect(a.ctx.destination);
      const tap = a.ctx.createChannelSplitter(2);
      a.merger.connect(tap);
      a.analysers = [0, 1].map((i) => {
        const an = a.ctx.createAnalyser();
        an.fftSize = 2048;
        tap.connect(an, i);
        return an;
      });
      this.meterLoop();
    },

    wirePlayers() {
      for (const key of ["original", "fixed"]) {
        const el = this.$refs["player_" + key];
        const url = this.result[key + "_url"];
        if (!el || !url) continue;
        if (el.getAttribute("src") !== url) {
          el.setAttribute("src", url);
          el.load();
        }
        if (!el.dataset.wired) {
          el.dataset.wired = "1";
          el.addEventListener("timeupdate", this.onTime);
          el.addEventListener("loadedmetadata", this.onTime);
          el.addEventListener("ended", () => { this.playing = false; });
        }
        if (this.audio.ctx && !this.audio.players[key]) this.wirePlayer(key);
      }
    },

    wirePlayer(key) {
      const a = this.audio;
      const el = this.$refs["player_" + key];
      if (!el || a.players[key]) return;
      const src = a.ctx.createMediaElementSource(el);
      const splitter = a.ctx.createChannelSplitter(2);
      src.connect(splitter);
      const gains = [0, 1, 2, 3].map(() => a.ctx.createGain());
      splitter.connect(gains[0], 0); gains[0].connect(a.merger, 0, 0);
      splitter.connect(gains[1], 0); gains[1].connect(a.merger, 0, 1);
      splitter.connect(gains[2], 1); gains[2].connect(a.merger, 0, 0);
      splitter.connect(gains[3], 1); gains[3].connect(a.merger, 0, 1);
      a.players[key] = { el, gains };
      this.applyMode(key);
    },

    applyMode(key) {
      const p = this.audio.players[key];
      if (!p) return;
      MODES[this.mode].forEach((v, i) => p.gains[i].gain.setTargetAtTime(v, this.audio.ctx.currentTime, 0.01));
    },

    meterLoop() {
      const a = this.audio;
      const buf = new Float32Array(a.analysers[0].fftSize);
      const tick = () => {
        if (!a.ctx) return;
        let rms = 0;
        for (const an of a.analysers) {
          an.getFloatTimeDomainData(buf);
          let sum = 0;
          for (let i = 0; i < buf.length; i++) sum += buf[i] * buf[i];
          rms = Math.max(rms, Math.sqrt(sum / buf.length));
        }
        const db = rms > 0 ? 20 * Math.log10(rms) : -100;
        this.meter = { db, pct: Math.max(0, Math.min(1, (db + 60) / 60)) * 100 };
        requestAnimationFrame(tick);
      };
      tick();
    },

    activeEl() {
      return this.$refs["player_" + this.source];
    },

    setSource(key) {
      if (key === "fixed" && !this.result?.fixed_url) return;
      const wasPlaying = this.playing;
      const t = this.activeEl()?.currentTime || 0;
      this.activeEl()?.pause();
      this.source = key;
      const el = this.activeEl();
      if (el) el.currentTime = t;
      if (wasPlaying) this.play();
      this.draw();
    },

    setMode(m) {
      this.mode = m;
      for (const key of Object.keys(this.audio.players)) this.applyMode(key);
    },

    togglePlay() {
      this.playing ? this.pause() : this.play();
    },

    play() {
      this.ensureGraph();
      this.wirePlayers();
      if (this.audio.ctx.state === "suspended") this.audio.ctx.resume();
      const el = this.activeEl();
      if (!el) return;
      el.play().then(() => { this.playing = true; }).catch((e) => { this.error = `Playback failed: ${e.message}`; });
    },

    pause() {
      for (const key of ["original", "fixed"]) this.$refs["player_" + key]?.pause();
      this.playing = false;
      this.stopAt = null;
    },

    seek(t) {
      for (const key of ["original", "fixed"]) {
        const el = this.$refs["player_" + key];
        if (el && el.getAttribute("src")) el.currentTime = Math.max(0, t);
      }
      this.onTime();
    },

    playWindow(key, w) {
      if (this.mode === "stereo") this.setMode("mono");
      this.setSource(key);
      this.seek(Math.max(0, w.from - LISTEN_PAD_S));
      this.stopAt = w.to + LISTEN_PAD_S;
      this.play();
    },

    onTime() {
      const el = this.activeEl();
      if (!el) return;
      this.currentTime = el.currentTime || 0;
      this.duration = el.duration || 0;
      if (this.stopAt != null && el.currentTime >= this.stopAt) this.pause();
      // Zoomed in and the playhead ran off the right edge: page the view along.
      if (this.view && this.playing && this.currentTime > this.view.end) {
        const span = this.view.end - this.view.start;
        this.setView(this.currentTime - span * 0.1, this.currentTime + span * 0.9);
        return;
      }
      this.draw();
    },

    onKey(e) {
      if (e.code === "Space" && !["INPUT", "TEXTAREA", "SELECT", "BUTTON"].includes(e.target.tagName) && this.result) {
        e.preventDefault();
        this.togglePlay();
      }
    },

    // ---- timelines ---------------------------------------------------------

    colorFor(phase, rms) {
      if (phase == null || rms < this.check.settings.silence_db) return "#d1d5db";
      const t = (phase + 1) / 2; // -1 red, 0 amber, +1 green
      const r = Math.round(220 - (220 - 22) * t);
      const g = Math.round(38 + (163 - 38) * t);
      const b = Math.round(38 + (74 - 38) * t);
      return `rgb(${r},${g},${b})`;
    },

    draw() {
      if (!this.result) return;
      const { start, end } = this.viewRange;
      const span = end - start || 1;
      const bucket = this.check.settings.bucket;
      const silence = this.check.settings.silence_db;

      for (const key of this.lanes) {
        const info = this.result[key];
        const canvas = this.canvasFor(key);
        if (!info || !canvas) continue;

        const dpr = window.devicePixelRatio || 1;
        const W = canvas.clientWidth || 800;
        const H = canvas.clientHeight || 64;
        canvas.width = Math.round(W * dpr);
        canvas.height = Math.round(H * dpr);
        const g = canvas.getContext("2d");
        g.setTransform(dpr, 0, 0, dpr, 0, 0);
        g.clearRect(0, 0, W, H);

        const x = (t) => ((t - start) / span) * W;
        const n = info.buckets.length;

        // Each pixel column averages the buckets under it; zoomed in, one bucket
        // spans several columns and they all read the same bucket.
        for (let px = 0; px < W; px++) {
          const t0 = start + (px / W) * span;
          const t1 = start + ((px + 1) / W) * span;
          const i0 = Math.max(0, Math.floor(t0 / bucket));
          const i1 = Math.min(n, Math.max(i0 + 1, Math.ceil(t1 / bucket)));
          if (i0 >= n) break;
          let sum = 0, cnt = 0, loud = -120;
          for (let i = i0; i < i1; i++) {
            const [p, r] = info.buckets[i];
            if (p != null && r > silence) { sum += p; cnt++; loud = Math.max(loud, r); }
          }
          g.fillStyle = this.colorFor(cnt ? sum / cnt : null, loud);
          const h = loud <= -120 ? 4 : Math.max(4, (H - 16) * Math.max(0, Math.min(1, (loud + 60) / 60)));
          g.fillRect(px, H - 12 - h, 1, h);
        }

        // Past the end of this file (the other lane may be longer)
        if (info.duration < end) {
          g.fillStyle = "#f3f4f6";
          g.fillRect(x(info.duration), 0, W - x(info.duration), H);
        }

        g.fillStyle = "#c7d2fe";
        for (const a of this.check.ayahs || []) {
          if (a.from < start || a.from > end) continue;
          g.fillRect(x(a.from), H - 10, 1, 10);
          if (span < 240) {
            g.fillStyle = "#6366f1";
            g.font = "9px ui-monospace, monospace";
            g.fillText(String(a.verse), x(a.from) + 2, H - 2);
            g.fillStyle = "#c7d2fe";
          }
        }

        for (const w of info.windows) {
          if (w.to < start || w.from > end) continue;
          const x0 = Math.max(0, x(w.from));
          const x1 = Math.min(W, Math.max(x0 + 2, x(w.to)));
          g.fillStyle = "rgba(220,38,38,.25)";
          g.fillRect(x0, 0, x1 - x0, H);
          g.strokeStyle = "#dc2626";
          g.strokeRect(x0 + 0.5, 0.5, x1 - x0 - 1, H - 1);
        }

        // Time labels at the edges when zoomed, so a close-up still says where it is
        if (this.view) {
          g.fillStyle = "#6b7280";
          g.font = "10px ui-monospace, monospace";
          g.fillText(this.formatSec(start), 3, 10);
          const label = this.formatSec(end);
          g.fillText(label, W - g.measureText(label).width - 3, 10);
        }

        // playhead
        if (this.currentTime >= start && this.currentTime <= end) {
          g.fillStyle = key === this.source ? "#111827" : "#9ca3af";
          g.fillRect(x(this.currentTime) - 1, 0, 2, H);
        }
      }
    },

    // ---- zoom & pan (shared by both lanes) ---------------------------------

    totalDuration() {
      return Math.max(...this.lanes.map((k) => this.result[k]?.duration || 0), 1);
    },

    zoomBy(factor, centre = null) {
      const { start, end } = this.viewRange;
      const span = end - start;
      const at = centre == null ? (start + end) / 2 : centre;
      const next = Math.max(2, Math.min(this.totalDuration(), span * factor));
      const frac = (at - start) / span;
      this.setView(at - frac * next, at + (1 - frac) * next);
    },

    zoomTo(from, to) {
      this.setView(from, to);
    },

    zoomToWindows() {
      const ws = this.original.windows;
      this.setView(Math.min(...ws.map((w) => w.from)) - 2, Math.max(...ws.map((w) => w.to)) + 2);
    },

    fitView() {
      this.view = null;
      this.draw();
    },

    panBy(dt) {
      const { start, end } = this.viewRange;
      this.setView(start + dt, end + dt);
    },

    // Clamp to the file and drop back to "whole file" when nothing is hidden.
    setView(from, to) {
      const total = this.totalDuration();
      let span = Math.max(2, Math.min(total, to - from));
      let start = Math.max(0, Math.min(from, total - span));
      this.view = span >= total - 0.01 ? null : { start, end: start + span };
      this.draw();
    },

    timeAt(event, key) {
      const rect = event.currentTarget.getBoundingClientRect();
      const { start, end } = this.viewRange;
      return start + ((event.clientX - rect.left) / rect.width) * (end - start);
    },

    onTimelineWheel(event, key) {
      // Plain wheel keeps scrolling the page; ctrl/⌘ zooms, shift (or a horizontal wheel) pans.
      const { start, end } = this.viewRange;
      if (event.ctrlKey || event.metaKey) {
        event.preventDefault();
        this.zoomBy(event.deltaY > 0 ? 1.25 : 0.8, this.timeAt(event, key));
      } else if (this.view && (event.shiftKey || Math.abs(event.deltaX) > Math.abs(event.deltaY))) {
        event.preventDefault();
        const delta = event.shiftKey ? event.deltaY : event.deltaX;
        this.panBy((delta / event.currentTarget.clientWidth) * (end - start));
      }
    },

    onTimelineDown(event, key) {
      this.drag.panning = true;
      this.drag.moved = false;
      this.drag.x = event.clientX;
      this.drag.start = this.viewRange.start;
    },

    onTimelineMove(event, key) {
      if (this.drag.panning && this.view) {
        const { start, end } = this.viewRange;
        const dt = ((this.drag.x - event.clientX) / event.currentTarget.clientWidth) * (end - start);
        if (Math.abs(event.clientX - this.drag.x) > 3) this.drag.moved = true;
        if (this.drag.moved) this.setView(this.drag.start + dt, this.drag.start + dt + (end - start));
        return;
      }
      const info = this.result[key];
      const t = this.timeAt(event, key);
      const ayah = (this.check.ayahs || []).find((a) => t >= a.from && t < a.to);
      const b = info.buckets[Math.floor(t / this.check.settings.bucket)];
      event.currentTarget.title =
        this.formatSec(t) + (ayah ? ` · ayah ${ayah.verse}` : "") + (b && b[0] != null ? ` · phase ${b[0].toFixed(2)} · ${b[1]} dB` : "");
    },

    onTimelineUp(event, key) {
      const moved = this.drag.moved;
      this.drag.panning = false;
      this.drag.moved = false;
      if (moved) return; // it was a pan, not a seek
      const t = Math.min(this.timeAt(event, key), this.result[key].duration);
      this.stopAt = null;
      this.seek(t);
      if (key !== this.source) this.setSource(key);
      this.play();
    },

    onTimelineLeave() {
      this.drag.panning = false;
      this.drag.moved = false;
    },

    // ---- formatting --------------------------------------------------------

    checkedLoss(i) {
      const w = this.result.fixed?.checked_windows?.[i];
      return w ? w.mono_loss_db : null;
    },

    fileMeta(info) {
      if (!info) return "";
      return `${info.file} · ${this.formatSec(info.duration)} · ${info.sample_rate} Hz · ${info.channels} ch` +
        (info.phase_mean != null ? ` · phase ${info.phase_mean.toFixed(2)}` : "") +
        (info.mono_loss_db != null ? ` · mono loss ${info.mono_loss_db} dB` : "");
    },

    laneSummary(info) {
      if (!info) return "";
      if (info.status === "mono") return "mono file";
      return info.windows.length ? `${info.windows.length} inverted window(s), ${info.inverted_secs}s` : "no inverted windows";
    },

    statusLabel(s) {
      return { inverted: "inverted", partial: "partly inverted", clean: "clean", mono: "mono" }[s] || s;
    },

    pillClass(s) {
      const colour = {
        inverted: "bg-red-600 text-white", fail: "bg-red-600 text-white",
        partial: "bg-amber-600 text-white",
        clean: "bg-green-600 text-white", pass: "bg-green-600 text-white",
        mono: "bg-gray-400 text-white"
      }[s] || "bg-gray-200 text-gray-700";
      return `inline-block px-2 rounded-full text-[11px] font-semibold leading-relaxed align-middle ${colour}`;
    },

    segClass(on) {
      return `text-xs px-2.5 py-1 border-0 border-r border-gray-300 last:border-r-0 disabled:text-gray-400 disabled:cursor-not-allowed ${
        on ? "bg-gray-900 text-white" : "bg-white hover:bg-gray-100"
      }`;
    },

    canvasFor(key) {
      const ref = this.$refs["tl_" + key];
      return Array.isArray(ref) ? ref[0] : ref;
    },

    db(v) {
      return v == null ? "–" : `${v.toFixed(1)} dB`;
    },

    formatSec(s) {
      if (!isFinite(s)) return "0:00.0";
      const m = Math.floor(s / 60);
      const r = s - m * 60;
      return `${m}:${r < 10 ? "0" : ""}${r.toFixed(1)}`;
    }
  }
};
</script>

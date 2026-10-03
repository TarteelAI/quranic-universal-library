<template>
  <div class="audio-repair">
    <p v-if="loading" class="text-gray-500">Loading ayah…</p>
    <p v-else-if="!ayah" class="text-red-600">Could not load this ayah.</p>

    <div v-else>
      <div class="flex items-center justify-between mb-3">
        <div class="text-sm text-gray-600">
          {{ recitation.name }} · {{ ayah.verse_key }} · surah {{ formatMs(durationMs) }}
        </div>
        <audio ref="player" controls class="h-8"></audio>
      </div>

      <!-- Two kinds of repair: swap whole words, or correct one sound in place. -->
      <div class="flex items-center gap-1 mb-3 border-b">
        <button
          v-for="t in tabs"
          :key="t.id"
          class="px-3 py-2 text-sm border-b-2 -mb-px transition"
          :class="tool === t.id
            ? 'border-indigo-600 text-indigo-700 font-medium'
            : 'border-transparent text-gray-500 hover:text-gray-700'"
          @click="tool = t.id"
        >
          {{ t.label }}
          <span class="block text-[11px] font-normal text-gray-400">{{ t.hint }}</span>
        </button>
      </div>

      <VowelRepair
        v-if="tool === 'vowel'"
        :session-id="sessionId"
        :verse-key="verseKey"
        :ayah="ayah"
        :config="vowelConfig"
        @applied="applyState"
      />

      <template v-if="tool === 'word'">
      <!-- Ayah words: click to start a span, shift-click to extend -->
      <div class="border rounded p-3 mb-4">
        <div class="flex items-center justify-between mb-2">
          <p class="text-xs text-gray-500">Click a word (shift-click another to select a range). Greyed words have no timing.</p>
          <label v-if="ayahHasLetters" class="flex items-center gap-1 text-xs">
            <input type="checkbox" v-model="letterMode" /> Letter mode
          </label>
          <span v-else class="text-[10px] text-gray-400">No letter data for this recitation</span>
        </div>
        <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
          <button
            v-for="word in ayah.words"
            :key="word.position"
            class="digitalkhatt-v2 px-2 py-1 rounded border text-2xl leading-none transition"
            :class="wordClass(word)"
            :disabled="word.start_ms == null"
            @click="onWordClick(word, $event)"
          >{{ word.text }}</button>
        </div>

        <!-- Letter picker for the selected word -->
        <div v-if="letterMode && selectedWordLetters.length" class="mt-3 pt-3 border-t">
          <p class="text-xs text-gray-500 mb-1">Pick the letter(s) to replace (shift-click for a range):</p>
          <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
            <button
              v-for="lt in selectedWordLetters"
              :key="lt.index"
              class="digitalkhatt-v2 px-2 py-1 rounded border text-xl leading-none"
              :class="targetLetterClass(lt)"
              @click="onTargetLetterClick(lt, $event)"
            >{{ lt.char }}<sub class="text-[9px] text-gray-400">{{ lt.index }}</sub></button>
          </div>
        </div>
      </div>

      <div v-if="hasSelection" class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- LEFT: source -->
        <div class="border rounded p-3">
          <h3 class="font-semibold text-sm mb-1">Source (to replace)</h3>
          <div class="digitalkhatt-v2 text-2xl text-right mb-2" dir="rtl">{{ targetText }}</div>

          <Waveform :session-id="sessionId" :start-ms="targetStart" :end-ms="targetEnd" color="rgba(220,38,38,0.6)" />

          <div class="flex items-center gap-2 mt-2 text-sm">
            <button class="btn btn-sm btn-secondary" @click="playSource">▶ Play source</button>
            <span class="text-xs text-gray-500">{{ targetEnd - targetStart }} ms</span>
          </div>

          <div class="grid grid-cols-2 gap-2 mt-2 text-xs">
            <div>
              <label class="block text-gray-500">start (ms)</label>
              <div class="flex items-center gap-1">
                <button class="btn btn-xs" @click="targetStart -= step">-</button>
                <input type="number" v-model.number="targetStart" class="form-control form-control-sm w-24" />
                <button class="btn btn-xs" @click="targetStart += step">+</button>
              </div>
            </div>
            <div>
              <label class="block text-gray-500">end (ms)</label>
              <div class="flex items-center gap-1">
                <button class="btn btn-xs" @click="targetEnd -= step">-</button>
                <input type="number" v-model.number="targetEnd" class="form-control form-control-sm w-24" />
                <button class="btn btn-xs" @click="targetEnd += step">+</button>
              </div>
            </div>
          </div>
        </div>

        <!-- RIGHT: candidates -->
        <div class="border rounded p-3">
          <div class="flex gap-2 mb-2 text-sm">
            <button class="btn btn-sm" :class="mode === 'search' ? 'btn-primary' : 'btn-outline-secondary'" @click="mode = 'search'">Find same word</button>
            <button class="btn btn-sm" :class="mode === 'manual' ? 'btn-primary' : 'btn-outline-secondary'" @click="mode = 'manual'">Manual</button>
          </div>

          <div v-if="mode === 'search'" class="mb-2">
            <button class="btn btn-sm btn-primary w-full" @click="findCandidates" :disabled="searching">
              {{ searching ? 'Searching…' : (toPos > fromPos ? 'Find same phrase' : 'Find same word') }}
            </button>
            <p v-if="truncated" class="text-xs text-amber-600 mt-1">Showing a capped subset.</p>
          </div>
          <div v-else class="flex gap-2 mb-2">
            <input v-model="manualRef" placeholder="18:31:6 or 18:31:6-7" class="form-control form-control-sm" @keyup.enter="manualLookup" />
            <button class="btn btn-sm btn-primary" @click="manualLookup">Look up</button>
          </div>

          <div class="space-y-2 max-h-96 overflow-y-auto">
            <div
              v-for="c in candidates"
              :key="c.verse_key + ':' + c.from_position + '-' + c.to_position"
              class="border rounded p-2 text-sm"
              :class="isChosen(c) ? 'border-blue-500 bg-blue-50' : ''"
            >
              <div class="flex justify-between items-center">
                <span class="text-xs text-gray-600">{{ c.verse_key }} w{{ c.from_position }}<span v-if="c.to_position > c.from_position">-{{ c.to_position }}</span></span>
                <span v-if="c.score != null" class="text-xs text-gray-400">{{ c.duration_ms }}ms · score {{ c.score }}</span>
              </div>
              <div class="digitalkhatt-v2 text-lg text-right" dir="rtl">{{ c.text }}</div>
              <Waveform v-if="c._wave" :session-id="sessionId" :chapter-audio-file-id="c.chapter_audio_file_id" :start-ms="c.start_ms" :end-ms="c.end_ms" />
              <div class="flex gap-1 mt-1">
                <button class="btn btn-xs btn-secondary" @click="auditionCandidate(c)">▶ Play</button>
                <button class="btn btn-xs btn-outline-secondary" @click="c._wave = !c._wave">wave</button>
                <button class="btn btn-xs btn-primary" @click="chooseCandidate(c)">Use</button>
              </div>
            </div>
            <p v-if="!candidates.length && !searching" class="text-xs text-gray-400">No candidates yet.</p>
          </div>
        </div>
      </div>

      <!-- Candidate editor -->
      <div v-if="chosen" class="border rounded p-3 mt-4 bg-yellow-50">
        <h3 class="font-semibold text-sm mb-2">Adjust & preview — {{ chosen.verse_key }} w{{ chosen.from_position }}<span v-if="chosen.to_position > chosen.from_position">-{{ chosen.to_position }}</span></h3>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <Waveform :session-id="sessionId" :chapter-audio-file-id="chosen.chapter_audio_file_id" :start-ms="candStart" :end-ms="candEnd" color="rgba(16,185,129,0.65)" />

            <div v-if="letterMode && candLetters.length" class="mt-2">
              <p class="text-xs text-gray-500 mb-1">Pick the source letter(s) (shift-click for a range):</p>
              <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
                <button
                  v-for="(lt, i) in candLetters"
                  :key="lt.word_position + '-' + lt.index"
                  class="digitalkhatt-v2 px-2 py-1 rounded border text-xl leading-none"
                  :class="candLetterClass(i)"
                  @click="onCandLetterClick(i, $event)"
                >{{ lt.char }}<sub class="text-[9px] text-gray-400">{{ lt.index }}</sub></button>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-2 mt-2 text-xs">
              <div>
                <label class="block text-gray-500">clip start</label>
                <div class="flex items-center gap-1">
                  <button class="btn btn-xs" @click="candStart -= step">-</button>
                  <input type="number" v-model.number="candStart" class="form-control form-control-sm w-24" />
                  <button class="btn btn-xs" @click="candStart += step">+</button>
                </div>
              </div>
              <div>
                <label class="block text-gray-500">clip end</label>
                <div class="flex items-center gap-1">
                  <button class="btn btn-xs" @click="candEnd -= step">-</button>
                  <input type="number" v-model.number="candEnd" class="form-control form-control-sm w-24" />
                  <button class="btn btn-xs" @click="candEnd += step">+</button>
                </div>
              </div>
            </div>
          </div>

          <div class="text-sm space-y-2">
            <!-- Measured fit: level, pitch and length are the three things that
                 give a splice away, so show all three rather than only loudness. -->
            <div class="rounded border bg-white p-2">
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs font-medium text-gray-700">Fit to the original</span>
                <div class="flex gap-1">
                  <button class="btn btn-xs btn-outline-secondary" @click="measureMatch" :disabled="matching">
                    {{ matching ? 'Measuring…' : 'Measure' }}
                  </button>
                  <button class="btn btn-xs btn-primary" @click="applyMatch" :disabled="!hasSuggestions">
                    Match all
                  </button>
                </div>
              </div>

              <table v-if="match" class="w-full text-[11px]">
                <thead class="text-gray-400">
                  <tr><th class="text-left font-normal"></th><th class="text-right font-normal">original</th>
                      <th class="text-right font-normal">candidate</th><th class="text-right font-normal">fix</th></tr>
                </thead>
                <tbody class="tabular-nums">
                  <tr>
                    <td class="text-gray-500">Loudness</td>
                    <td class="text-right">{{ fmt(match.target.lufs, ' LUFS') }}</td>
                    <td class="text-right">{{ fmt(match.candidate.lufs, ' LUFS') }}</td>
                    <td class="text-right" :class="match.suggested.gain_db ? 'text-indigo-600 font-medium' : 'text-gray-300'">
                      {{ match.suggested.gain_db ? signed(match.suggested.gain_db) + ' dB' : '—' }}
                    </td>
                  </tr>
                  <tr>
                    <td class="text-gray-500">Pitch</td>
                    <td class="text-right">{{ fmt(match.target.f0_median, ' Hz') }}</td>
                    <td class="text-right">{{ fmt(match.candidate.f0_median, ' Hz') }}</td>
                    <td class="text-right" :class="match.suggested.pitch_semitones ? 'text-indigo-600 font-medium' : 'text-gray-300'">
                      {{ match.suggested.pitch_semitones ? signed(match.suggested.pitch_semitones) + ' st' : '—' }}
                    </td>
                  </tr>
                  <tr>
                    <td class="text-gray-500">Length</td>
                    <td class="text-right">{{ match.target.duration_ms }} ms</td>
                    <td class="text-right">{{ match.candidate.duration_ms }} ms</td>
                    <td class="text-right" :class="match.suggested.tempo ? 'text-indigo-600 font-medium' : 'text-gray-300'">
                      {{ match.suggested.tempo ? match.suggested.tempo + '×' : '—' }}
                    </td>
                  </tr>
                </tbody>
              </table>
              <p v-else class="text-[11px] text-gray-400">
                Measure to see how this candidate's level, pitch and length compare.
              </p>

              <p v-for="w in (match && match.warnings) || []" :key="w"
                 class="mt-1 text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
                {{ w }}
              </p>
            </div>

            <label class="flex items-center gap-2 text-xs">
              <input type="checkbox" v-model="gainAuto" /> Auto loudness match on render
            </label>
            <div v-if="!gainAuto">
              <label class="block text-xs text-gray-500">gain (dB): {{ gainDb }}</label>
              <input type="range" min="-12" max="12" step="0.1" v-model.number="gainDb" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-500">pitch (semitones): {{ pitch }}</label>
              <input type="range" min="-4" max="4" step="0.1" v-model.number="pitch" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-500">time-stretch (tempo): {{ tempo }}× </label>
              <input type="range" min="0.7" max="1.3" step="0.01" v-model.number="tempo" class="w-full" />
              <button class="btn btn-xs btn-outline-secondary mt-1" @click="fitDuration">Fit to source duration</button>
            </div>
            <div>
              <label class="block text-xs text-gray-500">crossfade (ms): {{ crossfade }}</label>
              <input type="range" min="0" max="60" step="1" v-model.number="crossfade" class="w-full" />
            </div>
          </div>
        </div>

        <div class="flex gap-2 mt-3 items-center">
          <button class="btn btn-sm btn-secondary" @click="playSource">▶ A: source</button>
          <button class="btn btn-sm btn-secondary" @click="playClip(previewUrl)" :disabled="!previewUrl">▶ B: edited</button>
          <button class="btn btn-sm btn-primary" @click="preview" :disabled="previewing">{{ previewing ? 'Rendering…' : 'Render preview' }}</button>
          <button class="btn btn-sm btn-success" @click="apply" :disabled="applying">Apply ✓</button>
          <span v-if="previewGain != null" class="text-xs text-gray-500">applied gain {{ previewGain }} dB</span>
        </div>
      </div>

      </template>

      <!-- History + export -->
      <div class="border rounded p-3 mt-4">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-semibold text-sm">Repairs ({{ operations.length }})</h3>
          <div class="flex gap-1">
            <button class="btn btn-xs btn-outline-secondary" @click="undo" :disabled="!canUndo">↶ undo</button>
            <button class="btn btn-xs btn-outline-secondary" @click="redo" :disabled="!canRedo">redo ↷</button>
          </div>
        </div>
        <ol class="text-xs space-y-1 list-decimal list-inside">
          <li v-for="op in operations" :key="op.id">
            <template v-if="op.kind === 'vowel_repair'">
              <span class="inline-block px-1 rounded text-[10px] bg-indigo-100 text-indigo-700">sound</span>
              {{ op.verse_key }} w{{ op.word_position }}
              <span class="digitalkhatt-v2" style="font-size:15px;line-height:1">{{ op.target && op.target.char }}</span>
              ← {{ op.source && op.source.verse_key }} w{{ op.source && op.source.word_position }}
              <span v-if="op.metrics && op.metrics.after" class="text-gray-400">
                ({{ op.metrics.before.f2_balance }} → {{ op.metrics.after.f2_balance }} dB)
              </span>
            </template>
            <template v-else>
              <span class="inline-block px-1 rounded text-[10px] bg-gray-100 text-gray-600">word</span>
              {{ op.verse_key }} w{{ op.from_position || op.word_position }} ← {{ op.source && op.source.verse_key }} w{{ op.source && (op.source.from_position || op.source.word_position) }}
            </template>
          </li>
        </ol>
        <p v-if="!operations.length" class="text-xs text-gray-400">No repairs yet.</p>

        <div class="mt-3 pt-3 border-t flex gap-2 items-center">
          <select v-model="bitrate" class="form-control form-control-sm w-24">
            <option>128k</option><option>192k</option><option>256k</option><option>320k</option>
          </select>
          <button class="btn btn-sm btn-dark" @click="exportMp3" :disabled="!operations.length || status === 'rendering'">
            {{ status === 'rendering' ? 'Rendering…' : 'Export MP3' }}
          </button>
          <span v-if="status" class="text-xs" :class="status === 'failed' ? 'text-red-600' : 'text-gray-500'">{{ status }}</span>
          <a v-if="status === 'exported' && outputPath" :href="outputPath" class="btn btn-xs btn-success" download>⬇ Download repaired MP3</a>
        </div>
        <p v-if="outputPath && status === 'exported'" class="text-xs text-gray-500 mt-1">Output: {{ outputPath }}</p>
        <p v-if="lastError" class="text-xs text-red-600 mt-1">{{ lastError }}</p>
      </div>

      <p v-if="message" class="text-xs text-blue-700 mt-2">{{ message }}</p>
    </div>
  </div>
</template>

<script>
import Waveform from "./Waveform.vue";
import VowelRepair from "./VowelRepair.vue";

export default {
  components: { Waveform, VowelRepair },

  props: {
    sessionId: { type: String, required: true },
    verseKey: { type: String, required: true }
  },

  data() {
    return {
      loading: true,
      message: null,
      tool: "word",
      tabs: [
        { id: "word", label: "Replace word", hint: "swap a whole word or phrase" },
        { id: "vowel", label: "Fix pronunciation", hint: "correct one sound in place" }
      ],
      vowelConfig: {},
      recitation: {},
      chapter: {},
      audioUrl: null,
      durationMs: 0,
      crossfadeMs: 15,
      ayah: null,
      anchor: null,
      fromPos: null,
      toPos: null,
      targetStart: 0,
      targetEnd: 0,
      step: 20,
      letterMode: false,
      letterAnchor: null,
      targetLetterFrom: null,
      targetLetterTo: null,
      candLetters: [],
      candLetterAnchor: null,
      candLetterFrom: null,
      candLetterTo: null,
      mode: "search",
      manualRef: "",
      searching: false,
      truncated: false,
      candidates: [],
      chosen: null,
      candStart: 0,
      candEnd: 0,
      gainAuto: true,
      gainDb: 0,
      pitch: 0,
      tempo: 1,
      crossfade: 15,
      previewUrl: null,
      previewGain: null,
      match: null,
      matching: false,
      sourceClipUrl: null,
      previewing: false,
      applying: false,
      operations: [],
      canUndo: false,
      canRedo: false,
      status: null,
      outputPath: null,
      lastError: null,
      bitrate: "192k",
      pollTimer: null
    };
  },

  computed: {
    base() {
      return `/audio_repair/sessions/${this.sessionId}`;
    },
    hasSelection() {
      return this.fromPos != null && this.toPos != null;
    },
    selectedWords() {
      if (!this.hasSelection) return [];
      return this.ayah.words.filter((w) => w.position >= this.fromPos && w.position <= this.toPos);
    },
    targetText() {
      return this.selectedWords.map((w) => w.text).join(" ");
    },
    hasSuggestions() {
      const sg = this.match && this.match.suggested;
      return !!(sg && (sg.gain_db || sg.pitch_semitones || sg.tempo));
    },
    ayahHasLetters() {
      return this.ayah && this.ayah.words.some((w) => w.letters && w.letters.length);
    },
    // Letter picking only makes sense on a single selected word.
    selectedWordLetters() {
      if (!this.letterMode || !this.hasSelection || this.fromPos !== this.toPos) return [];
      const word = this.ayah.words.find((w) => w.position === this.fromPos);
      return (word && word.letters) || [];
    }
  },

  mounted() {
    this.loadData();
  },

  beforeUnmount() {
    if (this.pollTimer) clearInterval(this.pollTimer);
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

    async loadData() {
      try {
        const d = await this.api(`${this.base}/data?key=${encodeURIComponent(this.verseKey)}`);
        this.recitation = d.recitation;
        this.chapter = d.chapter;
        this.audioUrl = d.audio_url;
        this.durationMs = d.duration_ms;
        this.crossfadeMs = d.crossfade_ms;
        this.vowelConfig = d.vowel_repair || {};
        this.crossfade = d.crossfade_ms;
        this.ayah = d.ayah;
        this.applyState(d.session);
      } catch (e) {
        this.message = e.message;
      } finally {
        this.loading = false;
      }
    },

    applyState(s) {
      this.operations = s.operations || [];
      this.canUndo = s.can_undo;
      this.canRedo = s.can_redo;
      this.status = s.status;
      this.outputPath = s.output_path;
      this.lastError = s.last_error;
    },

    wordClass(word) {
      if (word.start_ms == null) return "opacity-30 cursor-not-allowed border-gray-100";
      const sel = this.hasSelection && word.position >= this.fromPos && word.position <= this.toPos;
      return sel ? "bg-blue-600 text-white border-blue-600" : "hover:bg-blue-50 border-gray-200";
    },

    onWordClick(word, e) {
      if (word.start_ms == null) return;
      if (e.shiftKey && this.anchor != null) {
        this.fromPos = Math.min(this.anchor, word.position);
        this.toPos = Math.max(this.anchor, word.position);
      } else {
        this.anchor = word.position;
        this.fromPos = word.position;
        this.toPos = word.position;
      }
      this.syncTargetRegion();
      this.letterAnchor = null;
      this.targetLetterFrom = null;
      this.targetLetterTo = null;
      this.candidates = [];
      this.chosen = null;
      this.previewUrl = null;
      this.sourceClipUrl = null;
      this.message = null;
      if (this.mode === "search") this.findCandidates();
    },

    // ---- letter-level selection ----

    letterRange(letters, fromIdx, toIdx) {
      const lo = Math.min(fromIdx, toIdx);
      const hi = Math.max(fromIdx, toIdx);
      const chosen = letters.filter((l) => l.index >= lo && l.index <= hi);
      return [Math.min(...chosen.map((l) => l.start_ms)), Math.max(...chosen.map((l) => l.end_ms))];
    },

    targetLetterClass(lt) {
      const sel = this.targetLetterFrom != null &&
        lt.index >= Math.min(this.targetLetterFrom, this.targetLetterTo) &&
        lt.index <= Math.max(this.targetLetterFrom, this.targetLetterTo);
      return sel ? "bg-red-600 text-white border-red-600" : "hover:bg-red-50 border-gray-200";
    },

    onTargetLetterClick(lt, e) {
      if (e.shiftKey && this.letterAnchor != null) {
        this.targetLetterFrom = this.letterAnchor;
        this.targetLetterTo = lt.index;
      } else {
        this.letterAnchor = lt.index;
        this.targetLetterFrom = lt.index;
        this.targetLetterTo = lt.index;
      }
      const [s, en] = this.letterRange(this.selectedWordLetters, this.targetLetterFrom, this.targetLetterTo);
      this.targetStart = s;
      this.targetEnd = en;
    },

    async fetchCandidateLetters(c) {
      this.candLetters = [];
      this.candLetterFrom = null;
      this.candLetterTo = null;
      this.candLetterAnchor = null;
      if (!this.letterMode) return;
      try {
        const q = new URLSearchParams({ verse_key: c.verse_key, from_position: c.from_position, to_position: c.to_position });
        const d = await this.api(`${this.base}/letters?${q}`);
        this.candLetters = d.letters || [];
      } catch (e) {
        this.candLetters = [];
      }
    },

    candLetterClass(i) {
      const sel = this.candLetterFrom != null &&
        i >= Math.min(this.candLetterFrom, this.candLetterTo) &&
        i <= Math.max(this.candLetterFrom, this.candLetterTo);
      return sel ? "bg-emerald-600 text-white border-emerald-600" : "hover:bg-emerald-50 border-gray-200";
    },

    onCandLetterClick(i, e) {
      if (e.shiftKey && this.candLetterAnchor != null) {
        this.candLetterFrom = this.candLetterAnchor;
        this.candLetterTo = i;
      } else {
        this.candLetterAnchor = i;
        this.candLetterFrom = i;
        this.candLetterTo = i;
      }
      const lo = Math.min(this.candLetterFrom, this.candLetterTo);
      const hi = Math.max(this.candLetterFrom, this.candLetterTo);
      const chosen = this.candLetters.slice(lo, hi + 1);
      this.candStart = Math.min(...chosen.map((l) => l.start_ms));
      this.candEnd = Math.max(...chosen.map((l) => l.end_ms));
    },

    syncTargetRegion() {
      const words = this.selectedWords;
      if (!words.length) return;
      this.targetStart = words[0].start_ms;
      this.targetEnd = words[words.length - 1].end_ms;
    },

    async findCandidates() {
      this.searching = true;
      try {
        const q = new URLSearchParams({ mode: "search", verse_key: this.verseKey, from_position: this.fromPos, to_position: this.toPos });
        const d = await this.api(`${this.base}/candidates?${q}`);
        this.candidates = d.candidates || [];
        this.truncated = d.truncated;
        if (!this.candidates.length) this.message = "No same-word/phrase candidates. Try Manual.";
      } catch (e) {
        this.message = e.message;
      } finally {
        this.searching = false;
      }
    },

    async manualLookup() {
      try {
        const q = new URLSearchParams({ mode: "manual", ref: this.manualRef, verse_key: this.verseKey, from_position: this.fromPos, to_position: this.toPos });
        const d = await this.api(`${this.base}/candidates?${q}`);
        this.candidates = d.candidates || [];
        if (!this.candidates.length) this.message = "No word found at that reference.";
      } catch (e) {
        this.message = e.message;
      }
    },

    isChosen(c) {
      return this.chosen && this.chosen.verse_key === c.verse_key && this.chosen.from_position === c.from_position && this.chosen.to_position === c.to_position;
    },

    chooseCandidate(c) {
      this.chosen = c;
      this.candStart = c.start_ms;
      this.candEnd = c.end_ms;
      this.previewUrl = null;
      this.previewGain = null;
      this.match = null;
      this.fetchCandidateLetters(c);
      this.playSource();
    },

    fmt(value, unit) {
      return value == null ? "—" : value + unit;
    },

    signed(value) {
      return (value > 0 ? "+" : "") + value;
    },

    async measureMatch() {
      if (!this.chosen) return;
      this.matching = true;
      try {
        this.match = await this.api(`${this.base}/match`, {
          method: "POST", body: { operation: this.buildOperation() }
        });
      } catch (e) {
        this.message = e.message;
      } finally {
        this.matching = false;
      }
    },

    // Writing the suggestions into the controls (rather than applying them
    // invisibly) keeps every correction inspectable and adjustable afterwards.
    applyMatch() {
      const sg = this.match && this.match.suggested;
      if (!sg) return;
      if (sg.gain_db != null) {
        this.gainAuto = false;
        this.gainDb = sg.gain_db;
      }
      if (sg.pitch_semitones != null) this.pitch = sg.pitch_semitones;
      if (sg.tempo != null) this.tempo = sg.tempo;
      this.previewUrl = null;
      this.message = "Applied the measured corrections — render a preview to hear them.";
    },

    fitDuration() {
      const clip = this.candEnd - this.candStart;
      const target = this.targetEnd - this.targetStart;
      if (clip > 0 && target > 0) {
        this.tempo = Math.min(1.3, Math.max(0.7, Number((clip / target).toFixed(3))));
      }
    },

    buildOperation() {
      const params = { pitch_semitones: this.pitch, tempo: this.tempo, crossfade_ms: this.crossfade };
      if (!this.gainAuto) params.gain_db = this.gainDb;
      return {
        verse_key: this.verseKey,
        from_position: this.fromPos,
        to_position: this.toPos,
        target: { start_ms: this.targetStart, end_ms: this.targetEnd },
        source: {
          chapter_audio_file_id: this.chosen.chapter_audio_file_id,
          start_ms: this.candStart,
          end_ms: this.candEnd,
          verse_key: this.chosen.verse_key,
          from_position: this.chosen.from_position,
          to_position: this.chosen.to_position,
          text: this.chosen.text
        },
        params: params
      };
    },

    playClip(url) {
      if (!url) return;
      const player = this.$refs.player;
      player.src = url;
      player.play();
    },

    async playSource() {
      try {
        const q = new URLSearchParams({
          chapter_audio_file_id: this.ayah.audio_file_id,
          start_ms: this.targetStart,
          end_ms: this.targetEnd,
          tag: `source_${this.verseKey}_${this.fromPos}_${this.toPos}`.replace(/[^a-zA-Z0-9_]/g, "")
        });
        const clip = await this.api(`${this.base}/audition?${q}`);
        this.sourceClipUrl = clip.url;
        this.playClip(clip.url);
      } catch (e) {
        this.message = e.message;
      }
    },

    async auditionCandidate(c) {
      try {
        const q = new URLSearchParams({
          chapter_audio_file_id: c.chapter_audio_file_id,
          start_ms: c.start_ms,
          end_ms: c.end_ms,
          tag: `cand_${c.verse_key}_${c.from_position}_${c.to_position}`.replace(/[^a-zA-Z0-9_]/g, "")
        });
        const clip = await this.api(`${this.base}/audition?${q}`);
        this.playClip(clip.url);
      } catch (e) {
        this.message = e.message;
      }
    },

    async preview() {
      this.previewing = true;
      try {
        const d = await this.api(`${this.base}/preview`, { method: "POST", body: { operation: this.buildOperation() } });
        this.previewUrl = d.url;
        this.previewGain = d.gain_db;
        this.playClip(d.url);
      } catch (e) {
        this.message = e.message;
      } finally {
        this.previewing = false;
      }
    },

    async apply() {
      this.applying = true;
      try {
        const d = await this.api(`${this.base}/add_operation`, { method: "POST", body: { operation: this.buildOperation() } });
        this.applyState(d);
        this.chosen = null;
        this.previewUrl = null;
        this.message = "Repair applied.";
      } catch (e) {
        this.message = e.message;
      } finally {
        this.applying = false;
      }
    },

    async undo() { this.applyState(await this.api(`${this.base}/undo`, { method: "POST" })); },
    async redo() { this.applyState(await this.api(`${this.base}/redo`, { method: "POST" })); },

    async exportMp3() {
      try {
        this.applyState(await this.api(`${this.base}/export`, { method: "POST", body: { bitrate: this.bitrate } }));
        this.startPolling();
      } catch (e) {
        this.message = e.message;
      }
    },

    startPolling() {
      if (this.pollTimer) clearInterval(this.pollTimer);
      this.pollTimer = setInterval(async () => {
        const s = await this.api(`${this.base}/status`);
        this.applyState(s);
        if (s.status !== "rendering") {
          clearInterval(this.pollTimer);
          this.pollTimer = null;
        }
      }, 3000);
    },

    formatMs(ms) {
      if (ms == null) return "—";
      const s = Math.floor(ms / 1000);
      return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
  }
};
</script>

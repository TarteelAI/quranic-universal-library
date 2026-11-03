<template>
  <div>
    <div v-if="!available" class="rounded border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800">
      Pronunciation repair is unavailable: the audio toolchain is not installed on this server.
    </div>

    <div v-else-if="!ayahHasLetters" class="rounded border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800">
      This recitation has no letter timings, so individual sounds cannot be addressed.
      Import them first, or use <strong>Replace word</strong> instead.
    </div>

    <template v-else>
      <!-- Step 1 — choose the sound -->
      <section :class="ui.step">
        <header :class="ui.head">
          <span :class="ui.num">1</span>
          <h3 :class="ui.title">Choose the sound to fix</h3>
          <span v-if="target" class="ml-auto flex items-center gap-1 text-xs text-gray-500 whitespace-nowrap">
            <span class="digitalkhatt-v2" style="font-size:15px;line-height:1">{{ display(target.char) }}</span>
            <span>· {{ target.duration_ms }} ms</span>
            <template v-if="target.next_char">
              <span>· then</span>
              <span class="digitalkhatt-v2" style="font-size:15px;line-height:1">{{ display(target.next_char) }}</span>
            </template>
          </span>
        </header>

        <div class="p-3">
          <p :class="ui.hint">Pick the word, then the exact letter or harakah inside it.</p>

          <div class="flex flex-wrap gap-1 justify-end mt-2" dir="rtl">
            <button
              v-for="word in wordsWithLetters"
              :key="word.position"
              class="digitalkhatt-v2 px-2 py-1 rounded border text-2xl leading-none transition"
              :class="word.position === wordPosition
                ? 'bg-indigo-600 text-white border-indigo-600'
                : 'border-gray-200 hover:bg-indigo-50'"
              @click="selectWord(word)"
            >{{ word.text }}</button>
          </div>

          <div v-if="wordLetters.length" class="mt-3 pt-3 border-t">
            <p :class="ui.hint" class="mb-2">
              Letters and harakat in recitation order; each chip is as wide as the sound is long.
              Shift-click a second chip to fix a run of sounds together.
            </p>
            <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
              <button
                v-for="lt in wordLetters"
                :key="lt.index"
                class="digitalkhatt-v2"
                :class="isLetterSelected(lt) ? ui.chipOn : ui.chip"
                :style="{ minWidth: chipWidth(lt) }"
                :title="`${lt.start_ms}–${lt.end_ms} ms (${lt.end_ms - lt.start_ms} ms)`"
                @click="selectLetter(lt, $event)"
              >
                <span class="text-xl leading-none">{{ display(lt.char) }}</span>
                <span :class="ui.chipMs">{{ lt.end_ms - lt.start_ms }}</span>
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Step 2 — choose a donor -->
      <section v-if="target" :class="ui.step">
        <header :class="ui.head">
          <span :class="ui.num">2</span>
          <h3 :class="ui.title">Choose where the correct sound comes from</h3>
          <div class="ml-auto flex items-center gap-2">
            <button class="btn btn-xs btn-outline-secondary" @click="playOriginal" :disabled="busy">
              ▶ Hear the problem
            </button>
            <button class="btn btn-xs btn-primary" @click="measureAll" :disabled="measuring || !donors.length">
              {{ measuring ? `Measuring ${measuredCount}/${donors.length}…` : 'Measure all' }}
            </button>
            <button v-if="measuring" class="btn btn-xs btn-outline-secondary" @click="cancelMeasure">Stop</button>
          </div>
        </header>

        <div class="p-3">
          <p :class="ui.hint">
            The same letter of the same word, recited correctly elsewhere by this reciter.
            Only the articulation is borrowed, never the audio, so another surah is fine.
            <strong>Measure all</strong> runs each repair for real and ranks by the result.
          </p>

          <p v-if="!donors.length" class="text-xs text-gray-400 mt-2">
            No other occurrence of this word has letter timings. Add one by hand below.
          </p>

          <ul v-else :class="ui.donorList">
            <li
              v-for="d in sortedDonors"
              :key="d.verse_key + ':' + d.word_position + ':' + d.letter_from + '-' + d.letter_to"
              :class="isChosen(d) ? ui.donorOn : ui.donor"
            >
              <div class="min-w-0 w-44 shrink-0">
                <div class="font-medium text-sm flex items-center gap-1 flex-wrap">
                  <span>{{ d.verse_key }} <span class="text-gray-400">w{{ d.word_position }}</span></span>
                  <span v-if="d.chars" class="digitalkhatt-v2 font-normal" style="font-size:15px;line-height:1">{{ display(d.chars) }}</span>
                  <span v-if="d.manual" :class="ui.tagInfo">added</span>
                  <span v-if="d.letter_source === 'draft'" :class="ui.tagWarn"
                        title="Letter timings from a segment-pipeline draft that is not imported yet">draft timings</span>
                </div>
                <div class="text-[11px] text-gray-500 flex items-center gap-1 flex-wrap">
                  <span>{{ d.duration_ms }} ms</span>
                  <template v-if="d.next_char">
                    <span>· then</span>
                    <span class="digitalkhatt-v2" style="font-size:15px;line-height:1">{{ display(d.next_char) }}</span>
                  </template>
                  <span v-if="sameFollowing(d)" :class="ui.tagGood">same next</span>
                </div>
              </div>

              <div class="flex-1 px-2 min-w-0">
                <Gauge v-if="d.after" :before="d.before.f2_balance" :after="d.after.f2_balance" compact />
                <div v-else class="text-[11px] text-gray-400">not measured</div>
              </div>

              <div class="text-right text-[11px] w-28 shrink-0">
                <template v-if="d.after">
                  <div :class="verdictClass(d.after.f2_balance)">{{ verdict(d.after.f2_balance) }}</div>
                  <div class="text-gray-400">join {{ d.after.max_f2_step }} Hz</div>
                </template>
                <div v-else-if="d._measuring" class="text-gray-400">measuring…</div>
                <div v-else-if="d._error" class="text-red-500 truncate" :title="d._error">failed</div>
              </div>

              <div class="flex gap-1 shrink-0">
                <button class="btn btn-xs btn-outline-secondary" @click="measureOne(d)"
                        :disabled="d._measuring" title="Measure this donor">↻</button>
                <button class="btn btn-xs btn-primary" @click="choose(d)">Use</button>
                <button v-if="d.manual" class="btn btn-xs btn-outline-secondary" @click="removeDonor(d)"
                        title="Remove this donor">✕</button>
              </div>
            </li>
          </ul>

          <!-- Add a donor by hand: any ayah, any word, any letters with the same count -->
          <div class="mt-3 rounded border border-dashed border-gray-300">
            <button class="w-full flex items-center gap-2 px-3 py-2 text-xs font-medium text-gray-600"
                    @click="custom.open = !custom.open">
              <span>{{ custom.open ? '▾' : '▸' }}</span>
              Add a donor from another ayah or word
              <span class="ml-auto text-[11px] font-normal text-gray-400">
                pick {{ target.letters.length }} sounded letter{{ target.letters.length === 1 ? '' : 's' }}
              </span>
            </button>

            <div v-if="custom.open" class="px-3 pb-3 pt-2 border-t space-y-3">
              <form class="flex items-center gap-2" @submit.prevent="loadCustomAyah">
                <input v-model.trim="custom.verseKey" placeholder="Ayah, e.g. 4:173"
                       class="form-control form-control-sm w-36" />
                <button type="submit" class="btn btn-xs btn-outline-secondary"
                        :disabled="!custom.verseKey || custom.loading">
                  {{ custom.loading ? 'Loading…' : 'Load ayah' }}
                </button>
                <span v-if="custom.ayah && custom.ayah.letter_source === 'draft'" :class="ui.tagWarn">
                  draft timings
                </span>
              </form>

              <p v-if="custom.error" class="text-[11px] text-red-600 leading-snug">{{ custom.error }}</p>

              <template v-if="custom.ayah">
                <div>
                  <p :class="ui.hint" class="mb-1">Word in {{ custom.ayah.verse_key }}:</p>
                  <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
                    <button
                      v-for="w in custom.ayah.words"
                      :key="w.position"
                      class="digitalkhatt-v2 px-2 py-1 rounded border text-xl leading-none transition"
                      :class="w.position === custom.wordPosition
                        ? 'bg-indigo-600 text-white border-indigo-600'
                        : 'border-gray-200 hover:bg-indigo-50'"
                      :title="`word ${w.position}`"
                      @click="selectCustomWord(w)"
                    >{{ w.text }}</button>
                  </div>
                </div>

                <div v-if="customWordLetters.length">
                  <p :class="ui.hint" class="mb-1">Letters (shift-click for a run):</p>
                  <div class="flex flex-wrap gap-1 justify-end" dir="rtl">
                    <button
                      v-for="lt in customWordLetters"
                      :key="lt.index"
                      class="digitalkhatt-v2"
                      :class="isCustomLetterSelected(lt) ? ui.chipOn : ui.chip"
                      :style="{ minWidth: chipWidth(lt) }"
                      :title="`${lt.start_ms}–${lt.end_ms} ms (${lt.end_ms - lt.start_ms} ms)`"
                      @click="selectCustomLetter(lt, $event)"
                    >
                      <span class="text-xl leading-none">{{ display(lt.char) }}</span>
                      <span :class="ui.chipMs">{{ lt.end_ms - lt.start_ms }}</span>
                    </button>
                  </div>
                </div>

                <div class="flex items-center gap-2">
                  <button class="btn btn-xs btn-primary" @click="addCustomDonor"
                          :disabled="!customCountMatches || custom.adding">
                    {{ custom.adding ? 'Adding…' : 'Add donor' }}
                  </button>
                  <span class="text-[11px]"
                        :class="custom.letterFrom == null ? 'text-gray-400' : (customCountMatches ? 'text-emerald-600' : 'text-amber-600')">
                    <template v-if="custom.letterFrom == null">Pick the letters to borrow.</template>
                    <template v-else>
                      {{ customSoundedCount }} of {{ target.letters.length }} sounded letter{{ target.letters.length === 1 ? '' : 's' }} picked
                    </template>
                  </span>
                </div>
              </template>
            </div>
          </div>
        </div>
      </section>

      <!-- Step 3 — listen, tune, apply -->
      <section v-if="chosen" :class="ui.stepActive">
        <header :class="ui.head">
          <span :class="ui.num">3</span>
          <h3 :class="ui.title">
            Listen and apply — donor {{ chosen.verse_key }} w{{ chosen.word_position }}
          </h3>
          <button class="ml-auto btn btn-xs btn-outline-secondary" @click="chosen = null">Change donor</button>
        </header>

        <div class="p-3 space-y-3">
          <div class="rounded border bg-white p-3">
            <div class="flex items-baseline justify-between mb-1">
              <span class="text-xs font-medium text-gray-600">Vowel colour</span>
              <span class="text-[11px] text-gray-400">where the sound reads, before → after</span>
            </div>
            <Gauge v-if="after" :before="before.f2_balance" :after="after.f2_balance" />
            <p v-else class="text-xs text-gray-400">Render a preview to measure the result.</p>

            <dl v-if="after" class="grid grid-cols-3 gap-2 mt-3 text-[11px]">
              <div>
                <dt class="text-gray-400">Reads as</dt>
                <dd :class="verdictClass(after.f2_balance)">{{ verdict(after.f2_balance) }}</dd>
              </div>
              <div>
                <dt class="text-gray-400">Join smoothness</dt>
                <dd :class="after.max_f2_step > 1200 ? 'text-amber-600' : 'text-gray-700'">
                  {{ after.max_f2_step }} Hz step
                  <span v-if="before" class="text-gray-400">(was {{ before.max_f2_step }})</span>
                </dd>
              </div>
              <div>
                <dt class="text-gray-400">Audio changed</dt>
                <dd class="text-gray-700">{{ changedSpan }}</dd>
              </div>
            </dl>

            <p v-if="warning"
               class="mt-2 text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
              {{ warning }}
            </p>
          </div>

          <div class="flex flex-wrap gap-2 items-center">
            <button class="btn btn-sm btn-secondary" @click="playOriginal" :disabled="busy">▶ A — original</button>
            <button class="btn btn-sm btn-secondary" @click="play(previewUrl)" :disabled="!previewUrl">▶ B — repaired</button>
            <button class="btn btn-sm btn-primary" @click="renderPreview" :disabled="busy">
              {{ previewing ? 'Rendering…' : 'Render preview' }}
            </button>
            <button class="btn btn-sm btn-success" @click="apply" :disabled="busy || !previewUrl">Apply ✓</button>
            <span class="text-[11px] text-gray-400">Length never changes, so later timings stay valid.</span>
          </div>

          <div class="rounded border bg-gray-50">
            <button class="w-full flex items-center gap-2 px-3 py-2 text-xs font-medium text-gray-600"
                    @click="showAdvanced = !showAdvanced">
              <span>{{ showAdvanced ? '▾' : '▸' }}</span>
              Advanced settings
              <span v-if="dirtyParams" :class="ui.tagWarn">changed</span>
              <span class="ml-auto text-[11px] font-normal text-gray-400">defaults suit most repairs</span>
            </button>

            <div v-if="showAdvanced" class="px-3 pb-3 space-y-3 border-t pt-3">
              <div v-for="c in controls" :key="c.key">
                <div class="flex items-baseline justify-between">
                  <label class="text-xs font-medium text-gray-700">{{ c.label }}</label>
                  <span class="text-xs tabular-nums"
                        :class="params[c.key] !== c.default ? 'text-indigo-600 font-medium' : 'text-gray-500'">
                    {{ params[c.key] }}{{ c.unit }}
                  </span>
                </div>
                <input type="range" class="w-full"
                       :min="c.min" :max="c.max" :step="c.step"
                       v-model.number="params[c.key]" @change="invalidate" />
                <p class="text-[11px] text-gray-400 leading-snug">{{ c.help }}</p>
              </div>
              <button class="btn btn-xs btn-outline-secondary" @click="resetParams" :disabled="!dirtyParams">
                Reset to defaults
              </button>
            </div>
          </div>
        </div>
      </section>

      <p v-if="error" class="text-xs text-red-600 mt-2">{{ error }}</p>
      <audio ref="player" class="hidden"></audio>
    </template>
  </div>
</template>

<script>
import Gauge from "./VowelGauge.vue";

// Tailwind scans this file as plain text, so utility strings defined here are
// generated exactly as if they were written inline in the template. A scoped
// SFC stylesheet would NOT work: Tailwind never sees it, and the CSS esbuild
// emits for it is not loaded on this page.
const UI = {
  step: "border rounded-lg mb-3 bg-white",
  stepActive: "border rounded-lg mb-3 bg-white border-indigo-300 ring-1 ring-indigo-100",
  head: "flex items-center gap-2 px-3 py-2 border-b bg-gray-50 rounded-t-lg",
  title: "text-sm font-semibold text-gray-800 m-0",
  num: "inline-flex items-center justify-center w-5 h-5 rounded-full bg-indigo-600 text-white text-[11px] font-semibold shrink-0",
  hint: "text-xs text-gray-500 leading-snug",
  chip: "flex flex-col items-center justify-center gap-0.5 px-2 py-1 rounded border border-gray-200 hover:bg-indigo-50 transition",
  chipOn: "flex flex-col items-center justify-center gap-0.5 px-2 py-1 rounded border bg-indigo-600 text-white border-indigo-600",
  chipMs: "text-[9px] opacity-60 tabular-nums",
  donorList: "divide-y border rounded mt-2",
  donor: "flex items-center gap-2 px-2 py-2 bg-white",
  donorOn: "flex items-center gap-2 px-2 py-2 bg-indigo-50",
  tagGood: "inline-block px-1 rounded text-[10px] align-middle bg-emerald-100 text-emerald-700",
  tagWarn: "inline-block px-1 rounded text-[10px] align-middle bg-amber-100 text-amber-700",
  tagInfo: "inline-block px-1 rounded text-[10px] align-middle bg-indigo-100 text-indigo-700"
};

const emptyCustom = () => ({
  open: false, verseKey: "", ayah: null, loading: false, adding: false, error: null,
  wordPosition: null, letterFrom: null, letterTo: null, letterAnchor: null
});

export default {
  name: "VowelRepair",
  components: { Gauge },

  props: {
    sessionId: { type: String, required: true },
    verseKey: { type: String, required: true },
    ayah: { type: Object, required: true },
    config: { type: Object, default: () => ({}) }
  },

  emits: ["applied"],

  data() {
    return {
      wordPosition: null,
      letterFrom: null,
      letterTo: null,
      letterAnchor: null,
      target: null,
      donors: [],
      chosen: null,
      params: {},
      showAdvanced: false,
      before: null,
      after: null,
      detail: null,
      previewUrl: null,
      previewing: false,
      applying: false,
      measuring: false,
      cancelled: false,
      custom: emptyCustom(),
      error: null
    };
  },

  computed: {
    ui() { return UI; },
    base() { return `/audio_repair/sessions/${this.sessionId}`; },
    available() { return this.config.available !== false; },
    controls() { return this.config.controls || []; },
    wordsWithLetters() {
      return (this.ayah.words || []).filter((w) => w.letters && w.letters.length);
    },
    ayahHasLetters() { return this.wordsWithLetters.length > 0; },
    wordLetters() {
      const w = (this.ayah.words || []).find((x) => x.position === this.wordPosition);
      return (w && w.letters) || [];
    },
    // Measured donors first, best result first; unmeasured keep server order.
    sortedDonors() {
      const scored = this.donors.filter((d) => d.after);
      const rest = this.donors.filter((d) => !d.after);
      scored.sort((a, b) => a.after.f2_balance - b.after.f2_balance);
      return [...scored, ...rest];
    },
    measuredCount() { return this.donors.filter((d) => d.after || d._error).length; },
    customWordLetters() {
      const words = (this.custom.ayah && this.custom.ayah.words) || [];
      const w = words.find((x) => x.position === this.custom.wordPosition);
      return (w && w.letters) || [];
    },
    // The repair pairs letters one to one, and letters that own no sound
    // (hamzat wasl, a sun letter's lam) are not counted on either side.
    customSoundedCount() {
      return this.customWordLetters.filter((lt) =>
        this.isCustomLetterSelected(lt) && lt.end_ms > lt.start_ms).length;
    },
    customCountMatches() {
      return !!this.target && this.custom.letterFrom != null &&
             this.customSoundedCount === this.target.letters.length;
    },
    busy() { return this.previewing || this.applying || this.measuring; },
    dirtyParams() { return this.controls.some((c) => this.params[c.key] !== c.default); },
    changedSpan() {
      const c = this.detail && this.detail.changed_ms;
      if (!c || c[0] == null) return "—";
      return `${Math.round(c[1] - c[0])} ms`;
    },
    warning() {
      if (!this.detail) return null;
      if (this.detail.unstable_frames > 0) {
        return `${this.detail.unstable_frames} frame(s) could not be modelled and were left untouched. ` +
               "Lowering Filter order usually fixes this.";
      }
      if (this.after && this.after.f2_balance > 4) {
        return "The sound barely moved. Try another donor, or raise Strength.";
      }
      return null;
    }
  },

  created() { this.resetParams(); },

  methods: {
    async api(url, { method = "GET", body = null } = {}) {
      const opts = { method, headers: { Accept: "application/json" } };
      if (body) {
        opts.headers["Content-Type"] = "application/json";
        opts.body = JSON.stringify(body);
      }
      if (method !== "GET") {
        const t = document.querySelector('meta[name="csrf-token"]');
        if (t) opts.headers["X-CSRF-Token"] = t.content;
      }
      const res = await fetch(url, opts);
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
      return data;
    },

    resetParams() {
      const next = {};
      this.controls.forEach((c) => { next[c.key] = c.default; });
      this.params = next;
      this.invalidate();
    },

    // Any parameter change makes the rendered preview and its metrics stale.
    invalidate() {
      this.previewUrl = null;
      this.after = null;
      this.detail = null;
    },

    // A bare harakah is a combining mark: on its own it has nothing to sit on and
    // renders as a near-invisible speck. Carry it on a tatweel (U+0640), the way
    // tajweed charts do -- the Arabic font draws that natively, whereas U+25CC
    // falls back to a cramped glyph in DigitalKhatt.
    display(char) {
      if (!char) return "";
      const isCombiningOnly = /^[\u064B-\u065F\u0670\u06D6-\u06ED\u0618-\u061A\u08F0-\u08FF]+$/.test(char);
      return isCombiningOnly ? "\u0640" + char : char;
    },

    chipWidth(lt) {
      const ms = lt.end_ms - lt.start_ms;
      return `${Math.max(34, Math.min(90, 28 + ms / 4))}px`;
    },

    selectWord(word) {
      this.wordPosition = word.position;
      this.letterFrom = null;
      this.letterTo = null;
      this.letterAnchor = null;
      this.target = null;
      this.donors = [];
      this.chosen = null;
      this.custom = { ...emptyCustom(), open: this.custom.open, verseKey: this.custom.verseKey };
      this.invalidate();
    },

    isLetterSelected(lt) {
      return this.letterFrom != null &&
             lt.index >= this.letterFrom && lt.index <= this.letterTo;
    },

    async selectLetter(lt, event) {
      if (event && event.shiftKey && this.letterAnchor != null) {
        this.letterFrom = Math.min(this.letterAnchor, lt.index);
        this.letterTo = Math.max(this.letterAnchor, lt.index);
      } else {
        this.letterAnchor = lt.index;
        this.letterFrom = lt.index;
        this.letterTo = lt.index;
      }

      this.chosen = null;
      this.invalidate();
      this.error = null;
      try {
        const q = new URLSearchParams({
          verse_key: this.verseKey,
          word_position: this.wordPosition,
          letter_from: this.letterFrom,
          letter_to: this.letterTo
        });
        const d = await this.api(`${this.base}/vowel_donors?${q}`);
        this.target = d.target;
        // Donors added by hand stay across a letter change only if they still
        // match the new selection; re-adding is cheap, a wrong pairing is not.
        this.donors = (d.donors || []).map((x) => ({ ...x, before: null, after: null }));
        this.custom.letterFrom = null;
        this.custom.letterTo = null;
        this.custom.letterAnchor = null;
        this.custom.error = null;
      } catch (e) {
        this.error = e.message;
      }
    },

    // Compare by base letter: the same consonant can carry a different tanween
    // mark elsewhere and still be the same sound to glide into.
    sameFollowing(d) {
      if (!this.target || !d.next_char || !this.target.next_char) return false;
      const strip = (s) => s.replace(/[ً-ٰٟۖ-ۭـ]/g, "");
      return strip(d.next_char) === strip(this.target.next_char);
    },

    operationFor(donor) {
      return {
        kind: "vowel_repair",
        verse_key: this.verseKey,
        word_position: this.wordPosition,
        letter_from: this.target.letter_from,
        letter_to: this.target.letter_to,
        target: {
          start_ms: this.target.start_ms,
          end_ms: this.target.end_ms,
          char: this.target.chars,
          // Per-letter spans; the server pairs these with the donor's to anchor
          // the time mapping letter by letter.
          letters: this.target.letters
        },
        source: {
          chapter_audio_file_id: donor.chapter_audio_file_id,
          start_ms: donor.start_ms,
          end_ms: donor.end_ms,
          verse_key: donor.verse_key,
          word_position: donor.word_position,
          letter_from: donor.letter_from,
          letter_to: donor.letter_to,
          char: donor.chars,
          letters: donor.letters
        },
        params: { ...this.params }
      };
    },

    async measureOne(donor) {
      donor._measuring = true;
      donor._error = null;
      try {
        const d = await this.api(`${this.base}/vowel_preview?measure_only=true`, {
          method: "POST",
          body: { operation: this.operationFor(donor) }
        });
        donor.before = d.before;
        donor.after = d.after;
        donor._detail = d.detail;
      } catch (e) {
        donor._error = e.message;
      } finally {
        donor._measuring = false;
      }
    },

    // Sequential on purpose: each run is CPU-bound, and results arriving one at
    // a time is more useful than all of them landing at once.
    async measureAll() {
      this.measuring = true;
      this.cancelled = false;
      for (const d of this.donors) {
        if (this.cancelled) break;
        if (d.after) continue;
        await this.measureOne(d);
      }
      this.measuring = false;
    },

    cancelMeasure() { this.cancelled = true; },

    async loadCustomAyah() {
      const key = this.custom.verseKey.replace(/\s+/g, "");
      if (!/^\d{1,3}:\d{1,3}$/.test(key)) {
        this.custom.error = "Enter an ayah as surah:ayah, e.g. 4:173.";
        return;
      }
      this.custom.loading = true;
      this.custom.error = null;
      this.custom.ayah = null;
      this.custom.wordPosition = null;
      this.custom.letterFrom = this.custom.letterTo = this.custom.letterAnchor = null;
      try {
        const q = new URLSearchParams({ mode: "ayah", donor_verse_key: key });
        this.custom.ayah = await this.api(`${this.base}/vowel_donors?${q}`);
        // Same word as the target, if it is in this ayah: the likely pick.
        const same = this.custom.ayah.words.find((w) => this.target && w.text === this.target.text);
        if (same) this.selectCustomWord(same);
      } catch (e) {
        this.custom.error = e.message;
      } finally {
        this.custom.loading = false;
      }
    },

    selectCustomWord(w) {
      this.custom.wordPosition = w.position;
      this.custom.letterFrom = this.custom.letterTo = this.custom.letterAnchor = null;
      this.custom.error = null;
    },

    isCustomLetterSelected(lt) {
      return this.custom.letterFrom != null &&
             lt.index >= this.custom.letterFrom && lt.index <= this.custom.letterTo;
    },

    selectCustomLetter(lt, event) {
      const c = this.custom;
      if (event && event.shiftKey && c.letterAnchor != null) {
        c.letterFrom = Math.min(c.letterAnchor, lt.index);
        c.letterTo = Math.max(c.letterAnchor, lt.index);
      } else {
        c.letterAnchor = c.letterFrom = c.letterTo = lt.index;
      }
      c.error = null;
    },

    async addCustomDonor() {
      const c = this.custom;
      c.adding = true;
      c.error = null;
      try {
        const q = new URLSearchParams({
          mode: "manual",
          verse_key: this.verseKey,
          word_position: this.wordPosition,
          letter_from: this.target.letter_from,
          letter_to: this.target.letter_to,
          donor_verse_key: c.ayah.verse_key,
          donor_word_position: c.wordPosition,
          donor_letter_from: c.letterFrom,
          donor_letter_to: c.letterTo
        });
        const d = await this.api(`${this.base}/vowel_donors?${q}`);
        if (this.donors.some((x) => this.sameDonor(x, d))) {
          c.error = "That donor is already in the list.";
          return;
        }
        const donor = { ...d, before: null, after: null };
        this.donors.unshift(donor);
        this.measureOne(this.donors[0]);
      } catch (e) {
        c.error = e.message;
      } finally {
        c.adding = false;
      }
    },

    removeDonor(d) {
      if (this.isChosen(d)) this.chosen = null;
      this.donors = this.donors.filter((x) => x !== d);
    },

    sameDonor(a, b) {
      return a.verse_key === b.verse_key && a.word_position === b.word_position &&
             a.letter_from === b.letter_from && a.letter_to === b.letter_to;
    },

    isChosen(d) {
      return !!this.chosen && this.sameDonor(this.chosen, d);
    },

    choose(d) {
      this.chosen = d;
      this.before = d.before;
      this.after = d.after;
      this.detail = d._detail || null;
      this.previewUrl = null;
      this.renderPreview();
    },

    async renderPreview() {
      if (!this.chosen) return;
      this.previewing = true;
      this.error = null;
      try {
        const d = await this.api(`${this.base}/vowel_preview`, {
          method: "POST",
          body: { operation: this.operationFor(this.chosen) }
        });
        this.before = d.before;
        this.after = d.after;
        this.detail = d.detail;
        this.previewUrl = d.url;
        this.chosen.before = d.before;
        this.chosen.after = d.after;
        this.chosen._detail = d.detail;
        this.play(d.url);
      } catch (e) {
        this.error = e.message;
      } finally {
        this.previewing = false;
      }
    },

    async apply() {
      this.applying = true;
      try {
        const op = this.operationFor(this.chosen);
        op.metrics = { before: this.before, after: this.after };
        const d = await this.api(`${this.base}/add_operation`, {
          method: "POST", body: { operation: op }
        });
        this.$emit("applied", d);
        this.chosen = null;
        this.invalidate();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.applying = false;
      }
    },

    async playOriginal() {
      if (!this.target) return;
      try {
        const q = new URLSearchParams({
          chapter_audio_file_id: this.ayah.audio_file_id,
          start_ms: this.target.start_ms,
          end_ms: this.target.end_ms,
          tag: `vowel_${this.verseKey}_${this.wordPosition}_${this.letterFrom}_${this.letterTo}`.replace(/[^a-zA-Z0-9_]/g, "")
        });
        const clip = await this.api(`${this.base}/audition?${q}`);
        this.play(clip.url);
      } catch (e) {
        this.error = e.message;
      }
    },

    play(url) {
      if (!url) return;
      const p = this.$refs.player;
      p.src = url;
      p.play();
    },

    verdict(balance) {
      if (balance == null) return "—";
      if (balance > 4) return "ḍamma-like (u)";
      if (balance < -4) return "kasra-like (i)";
      return "between";
    },

    verdictClass(balance) {
      if (balance == null) return "text-gray-400";
      if (balance < -4) return "text-emerald-600 font-medium";
      if (balance > 4) return "text-red-600 font-medium";
      return "text-amber-600 font-medium";
    }
  }
};
</script>

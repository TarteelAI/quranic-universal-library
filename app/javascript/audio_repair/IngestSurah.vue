<template>
  <div class="ingest-surah">
    <div v-if="error" class="text-sm text-red-700 bg-red-50 border border-red-200 rounded p-2 mb-3">{{ error }}</div>

    <div v-if="s">
      <div class="flex items-center justify-between flex-wrap gap-2 mb-3">
        <div class="text-sm">
          <span class="text-xs px-2 py-1 rounded" :class="statusClass">{{ s.status }}</span>
          <span v-if="s.trim_approved_at" class="text-xs text-gray-500 ml-2">trim approved</span>
          <span v-if="!s.expects_head_trim" class="text-xs text-gray-400 ml-2">no preceding basmala</span>
        </div>
        <div class="flex items-center gap-2">
          <button
            v-if="canDownload"
            class="btn btn-sm btn-primary"
            :disabled="busy"
            @click="downloadAgain"
          >{{ s.status === 'failed' ? 'Retry download' : 'Download audio' }}</button>
          <button
            v-if="downloading"
            class="btn btn-sm btn-outline-danger"
            :disabled="busy"
            @click="cancelDownload"
          >Cancel download</button>
          <a :href="backUrl" class="btn btn-sm btn-outline-secondary">← back to the run</a>
        </div>
      </div>

      <div v-if="s.status === 'failed' && s.last_error" class="text-xs text-red-700 bg-red-50 border border-red-200 rounded p-2 mb-3 break-all">
        {{ s.last_error }}
      </div>
      <div v-if="downloading" class="mb-3">
        <div v-if="s.status === 'queued'" class="text-xs text-gray-600 mb-1">Queued — waiting for a free download slot…</div>
        <div v-else class="text-xs text-gray-600 mb-1">
          Downloading {{ mb(s.bytes_downloaded) }}<template v-if="s.bytes_total"> of {{ mb(s.bytes_total) }}</template>
        </div>
        <div class="w-full bg-gray-200 rounded h-1.5 overflow-hidden">
          <div class="h-1.5 bg-indigo-600 transition-all" :style="{ width: (s.percent || 0) + '%' }"></div>
        </div>
      </div>

      <div v-if="s.worker_running === false" class="text-xs text-amber-900 bg-amber-50 border border-amber-300 rounded p-2 mb-3">
        No background worker is running. Downloads and encodes wait in the queue until Sidekiq starts
        (<span class="font-mono">bundle exec sidekiq</span>).
      </div>

      <!-- Pipeline: where this surah is -->
      <ol class="flex flex-wrap gap-1 mb-3 text-xs">
        <li
          v-for="(step, i) in steps"
          :key="step.key"
          class="px-2 py-1 rounded border"
          :class="stepClass(step.key)"
        >
          {{ i + 1 }}. {{ step.label }}
        </li>
      </ol>

      <!-- ===== 1. Download ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">1. Download · original</span>
          <span class="text-[11px] text-gray-500">as downloaded, never modified</span>
        </header>
        <div class="p-3">
          <template v-if="s.files.original">
            <dl class="grid grid-cols-2 md:grid-cols-6 gap-2 text-xs mb-2">
              <div v-for="f in facts(s.files.original)" :key="f.k">
                <dt class="text-gray-500">{{ f.k }}</dt>
                <dd class="font-mono">{{ f.v }}</dd>
              </div>
            </dl>
            <audio :src="s.files.original.url" controls preload="none" class="w-full h-9"></audio>
            <p class="text-[11px] text-gray-400 mt-1 font-mono break-all">{{ s.files.original.path }}</p>
            <p class="text-[11px] text-gray-400 break-all">source: {{ s.source_url }}</p>
          </template>
          <div v-else class="flex items-center gap-2 flex-wrap">
            <p class="text-xs text-gray-500">Not downloaded yet.</p>
            <a v-if="s.source_url" :href="s.source_url" target="_blank" rel="noopener noreferrer" class="text-[11px] text-indigo-600 hover:underline break-all">{{ s.source_url }} ↗</a>
          </div>
        </div>
      </section>

      <!-- ===== 2. Trim ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">2. Trim</span>
          <span class="text-[11px] text-gray-500">remove the basmala, isti'adha or a closing du'a</span>
        </header>
        <div class="p-3">
          <template v-if="s.files.original">
            <IngestTrim
              :key="trimKey"
              :item="s"
              :item-url="itemUrl"
              :detect-url="detectUrl"
              :approve-url="approveUrl"
              @close="trimKey++"
              @updated="onTrimUpdated"
            />
            <div class="mt-3 flex items-center gap-2 flex-wrap text-xs">
              <span class="text-gray-500">Preview the saved cut ({{ fmt(s.trimmed.start_ms) }} – {{ fmt(s.trimmed.end_ms) }}, keeps {{ fmt(s.trimmed.duration_ms) }}):</span>
              <button class="btn btn-sm btn-dark" @click="playTrimmed">▶ play trimmed</button>
              <button class="btn btn-sm btn-outline-secondary" @click="stopTrimmed">■</button>
              <span class="text-gray-500 font-mono">{{ fmt(trimPlayhead) }}</span>
            </div>
            <p class="text-[11px] text-gray-400 mt-1">
              No trimmed file is kept on disk: the cut is applied during the encode, so this plays the original between the two cut points.
            </p>
          </template>
          <p v-else class="text-xs text-gray-500">Download the surah first.</p>
        </div>
      </section>

      <!-- ===== 3. Encode ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">3. Encode</span>
          <span class="text-[11px] text-gray-500">{{ s.formats.join(', ') }} · tagged with surah, reciter and album metadata</span>
        </header>
        <div class="p-3">
          <div class="flex items-end gap-3 flex-wrap mb-3">
            <label class="text-xs text-gray-600">
              MP3 bitrate for this surah
              <select v-model="bitrate" class="form-control form-control-sm block mt-1">
                <option value="64k">64k</option>
                <option value="96k">96k</option>
                <option value="128k">128k</option>
                <option value="160k">160k</option>
                <option value="192k">192k</option>
                <option value="source">match source</option>
              </select>
            </label>
            <button class="btn btn-sm btn-dark" :disabled="busy || encoding || !canEncode" @click="reencode">
              {{ encoding ? 'Encoding…' : (hasEncoded ? 'Re-encode' : 'Encode') }}
            </button>
            <p class="text-[11px] text-gray-500 flex-1 min-w-[240px]">
              <template v-if="!s.trim_approved_at">Save a trim (or choose “No trim”) first. </template>
              Overrides the run's bitrate ({{ s.ingest_bitrate }}) for this surah only. Every format is rebuilt from the
              original, so it is safe to repeat.
            </p>
          </div>
          <div v-if="encoding && s.progress_stage" class="mb-3">
            <div class="text-xs text-gray-600 mb-1">{{ s.progress_stage.label }} · step {{ s.progress_stage.done + 1 }} of {{ s.progress_stage.total }}</div>
            <div class="w-full bg-gray-200 rounded h-1.5 overflow-hidden">
              <div class="h-1.5 bg-indigo-600 transition-all" :style="{ width: Math.round((s.progress_stage.done / s.progress_stage.total) * 100) + '%' }"></div>
            </div>
          </div>
          <div v-for="kind in ['mp3', 'opus', 'wav']" :key="kind" class="mb-4 last:mb-0">
            <div class="flex items-baseline justify-between">
              <span class="text-xs font-semibold uppercase">{{ kind }}</span>
              <span v-if="!s.files[kind]" class="text-[11px] text-gray-400">not encoded</span>
            </div>
            <template v-if="s.files[kind]">
              <dl class="grid grid-cols-2 md:grid-cols-6 gap-2 text-xs my-1">
                <div v-for="f in facts(s.files[kind])" :key="f.k">
                  <dt class="text-gray-500">{{ f.k }}</dt>
                  <dd class="font-mono">{{ f.v }}</dd>
                </div>
              </dl>
              <div v-if="s.files[kind].tags && Object.keys(s.files[kind].tags).length" class="text-[11px] text-gray-500 mb-1">
                <span v-for="(v, k) in s.files[kind].tags" :key="k" class="mr-3"><span class="text-gray-400">{{ k }}</span> {{ v }}</span>
              </div>
              <audio :src="s.files[kind].url" controls preload="none" class="w-full h-9"></audio>
              <p class="text-[11px] text-gray-400 mt-1 font-mono break-all">{{ s.files[kind].path }}</p>
            </template>
          </div>
        </div>
      </section>

      <!-- ===== 4. Validate ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">4. Validate</span>
          <span class="text-[11px] text-gray-500">does it play correctly, including on a mono speaker</span>
        </header>
        <div class="p-3">
          <div v-if="hasChecks" class="grid md:grid-cols-2 gap-2 text-xs mb-3">
            <div class="flex items-center gap-2">
              <span :class="s.checks.channels_ok ? 'text-green-700' : 'text-red-700'">
                {{ s.checks.channels_ok ? '✓' : '✕' }}
              </span>
              <span>
                Mono/stereo
                <span v-if="s.checks.mono_loss_db != null" class="text-gray-500">
                  — summing to mono loses {{ Number(s.checks.mono_loss_db).toFixed(1) }} dB
                </span>
                <span v-else-if="s.checks.note" class="text-gray-500">— {{ s.checks.note }}</span>
              </span>
            </div>
            <div class="flex items-center gap-2">
              <span :class="s.checks.duration_ok ? 'text-green-700' : 'text-red-700'">
                {{ s.checks.duration_ok ? '✓' : '✕' }}
              </span>
              <span>
                Duration
                <span v-if="s.checks.duration_drift_ms != null" class="text-gray-500">
                  — {{ s.checks.duration_drift_ms }}ms from expected
                </span>
              </span>
            </div>
          </div>
          <p v-else class="text-xs text-gray-500 mb-3">No checks yet — they run automatically after encoding.</p>

          <div v-if="s.files.mp3" class="mb-3">
            <div class="flex items-center gap-2 flex-wrap mb-1">
              <span class="text-xs font-semibold">Listen to the MP3</span>
              <label class="text-xs flex items-center gap-1">
                <input v-model="mono" type="checkbox" @change="applyMono" /> play as mono (both channels summed)
              </label>
            </div>
            <audio ref="validateAudio" :src="s.files.mp3.url" controls preload="none" class="w-full h-9" @play="applyMono"></audio>
            <p class="text-[11px] text-gray-500 mt-1">
              With mono on, this is what a single phone speaker plays. If the voice thins out or vanishes, one channel is phase-inverted.
            </p>
          </div>

          <div class="flex items-center gap-2 flex-wrap">
            <button class="btn btn-sm btn-outline-secondary" :disabled="polarityBusy || !s.files.mp3" @click="runPolarity">
              {{ polarityBusy ? 'Starting…' : 'Full polarity check on the MP3' }}
            </button>
            <a v-if="polarityUrl" :href="polarityUrl" target="_blank" class="text-xs text-indigo-700 underline">
              open the polarity report →
            </a>
          </div>

          <form v-if="repairUrl && (s.files.mp3 || s.files.wav)" :action="repairUrl" method="post" target="_blank"
                class="mt-3 pt-3 border-t flex items-center gap-2 flex-wrap">
            <input type="hidden" name="authenticity_token" :value="csrfToken" />
            <input type="hidden" name="source" value="ingest" />
            <input type="hidden" name="ingest_item_id" :value="itemId" />
            <input type="hidden" name="tool" value="cut" />
            <button type="submit" class="btn btn-sm btn-outline-danger">✂ Remove repeated sections…</button>
            <span class="text-[11px] text-gray-500">
              Reciter went back and recited an ayah again? Open this encode in the audio repair tool: it finds the repeats,
              lets you drag out what to remove, and exports the final file.
            </span>
          </form>
        </div>
      </section>

      <!-- ===== 5. Upload / save ===== -->
      <section class="border rounded">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">5. Upload or save <span class="font-normal text-gray-400">(optional)</span></span>
          <span class="text-[11px] text-gray-500">push to the CDN, or keep a copy yourself</span>
        </header>
        <div class="p-3">
          <div class="flex items-center gap-2 flex-wrap mb-2">
            <button class="btn btn-sm btn-dark" :disabled="busy || uploading || !hasEncoded || !s.upload_path" @click="upload">
              {{ uploading ? 'Uploading…' : 'Upload to CDN' }}
            </button>
            <span v-if="s.upload_path" class="text-xs text-gray-600 font-mono">{{ s.upload_path }}/&lt;format&gt;/{{ String(s.chapter_id).padStart(3, '0') }}.&lt;format&gt;</span>
            <span v-else class="text-xs text-gray-500">Set the CDN path on <a :href="backUrl" class="underline">the run page</a> first.</span>
          </div>
          <div v-if="s.uploads && Object.keys(s.uploads).length" class="text-[11px] text-teal-800 mb-2">
            Uploaded: <span v-for="(u, k) in s.uploads" :key="k" class="font-mono mr-2">{{ u.key }}</span>
          </div>
          <div class="flex items-center gap-2 flex-wrap text-xs">
            <span class="text-gray-500">Save to your computer:</span>
            <a v-for="(url, kind) in s.download_urls" :key="kind" :href="url" class="btn btn-sm btn-outline-secondary">{{ kind }} ↓</a>
            <span class="text-[11px] text-gray-400">Files also stay on the server under <span class="font-mono">{{ s.paths && s.paths[0] ? s.paths[0].path.replace(/\/[^/]+\/[^/]+$/, '') : 'data/audio' }}</span>.</span>
          </div>
        </div>
      </section>
    </div>
    <p v-else>Loading…</p>
  </div>
</template>

<script>
import IngestTrim from "./IngestTrim.vue";

export default {
  name: "IngestSurah",
  components: { IngestTrim },
  props: {
    dataUrl: { type: String, required: true },
    reencodeUrl: { type: String, required: true },
    retryUrl: { type: String, required: true },
    cancelUrl: { type: String, required: true },
    uploadUrl: { type: String, required: true },
    itemUrl: { type: String, required: true },
    detectUrl: { type: String, required: true },
    approveUrl: { type: String, required: true },
    polarityUrlEndpoint: { type: String, required: true },
    backUrl: { type: String, required: true },
    repairUrl: { type: String, default: null },
    itemId: { type: String, default: null }
  },
  data() {
    return {
      s: null,
      error: null,
      busy: false,
      polarityBusy: false,
      polarityUrl: null,
      bitrate: "128k",
      trimAudio: null,
      trimPlayhead: 0,
      trimTimer: null,
      pollTimer: null,
      trimKey: 0,
      mono: false,
      audioCtx: null,
      monoNodes: null,
      steps: [
        { key: "download", label: "Download" },
        { key: "trim", label: "Trim" },
        { key: "encode", label: "Encode" },
        { key: "validate", label: "Validate" },
        { key: "upload", label: "Upload / save" }
      ]
    };
  },
  computed: {
    csrfToken() {
      const meta = document.querySelector('meta[name="csrf-token"]');
      return meta ? meta.content : "";
    },
    // A surah whose download failed, or that has no original on disk.
    canDownload() {
      return this.s && (this.s.status === "failed" || !this.s.files.original) && !this.downloading;
    },
    // Queued or mid-transfer. "pending" is not downloading: nothing will
    // fetch it until someone asks.
    downloading() {
      return this.s && ["queued", "downloading"].includes(this.s.status);
    },
    encoding() {
      return this.s && this.s.status === "encoding";
    },
    uploading() {
      return this.s && this.s.status === "uploading";
    },
    hasEncoded() {
      return this.s && !!this.s.files.mp3;
    },
    canEncode() {
      return this.s && !!this.s.files.original && !!this.s.trim_approved_at;
    },
    hasChecks() {
      return this.s && this.s.checks && Object.keys(this.s.checks).length > 0;
    },
    statusClass() {
      const map = {
        failed: "bg-red-100 text-red-800",
        encoding: "bg-blue-100 text-blue-800",
        verified: "bg-green-100 text-green-800",
        encoded: "bg-amber-100 text-amber-800"
      };
      return map[this.s.status] || "bg-gray-100 text-gray-700";
    }
  },
  mounted() {
    this.load();
  },
  beforeUnmount() {
    if (this.audioCtx) this.audioCtx.close();
    this.stopTrimmed();
    clearInterval(this.pollTimer);
  },
  methods: {
    fmt(ms) {
      if (ms == null) return "—";
      const total = Math.max(0, ms) / 1000;
      const m = Math.floor(total / 60);
      const sec = total % 60;
      return m > 0 ? `${m}:${sec.toFixed(1).padStart(4, "0")}` : `${sec.toFixed(2)}s`;
    },

    mb(bytes) {
      if (!bytes) return "—";
      return bytes >= 1048576 ? `${(bytes / 1048576).toFixed(1)} MB` : `${(bytes / 1024).toFixed(0)} KB`;
    },

    facts(f) {
      return [
        { k: "codec", v: f.codec || "—" },
        { k: "duration", v: this.fmt(f.duration_ms) },
        { k: "size", v: this.mb(f.bytes) },
        { k: "bitrate", v: f.bitrate_kbps ? `${f.bitrate_kbps}k` : "—" },
        { k: "channels", v: f.channels === 1 ? "mono" : f.channels === 2 ? "stereo" : f.channels || "—" },
        { k: "sample rate", v: f.sample_rate ? `${(f.sample_rate / 1000).toFixed(1)} kHz` : "—" }
      ];
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

    async load() {
      try {
        const data = await this.api(this.dataUrl);
        this.s = data;
        this.bitrate = data.bitrate || "128k";
        if (this.isWorking(data)) this.poll();
      } catch (e) {
        this.error = e.message;
      }
    },

    isWorking(data) {
      return ["encoding", "queued", "downloading", "uploading"].includes(data.status) || !!data.working;
    },

    // A cut was detected or approved (approving starts the encode): reload
    // the whole page state, files included, and follow the encode.
    async onTrimUpdated() {
      try {
        this.s = await this.api(this.dataUrl);
        if (this.isWorking(this.s)) this.poll();
      } catch (e) {
        this.error = e.message;
      }
    },

    async downloadAgain() {
      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        body.append("item_id", this.s.id);
        await this.api(this.retryUrl, { method: "POST", body });
        this.s = await this.api(this.dataUrl);
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    async cancelDownload() {
      if (!confirm("Cancel this download? The partial file is deleted.")) return;
      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        body.append("item_ids[]", this.s.id);
        await this.api(this.cancelUrl, { method: "POST", body });
        this.s = await this.api(this.dataUrl);
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    poll() {
      clearInterval(this.pollTimer);
      this.pollTimer = setInterval(async () => {
        try {
          const data = await this.api(this.dataUrl);
          this.s = data;
          if (!this.isWorking(data)) clearInterval(this.pollTimer);
        } catch {
          clearInterval(this.pollTimer);
        }
      }, 2000);
    },

    async reencode() {
      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        body.append("bitrate", this.bitrate);
        this.s = await this.api(this.reencodeUrl, { method: "POST", body });
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    stepClass(key) {
      const order = this.steps.map((st) => st.key);
      const current = this.s.next_step === "done" ? order.length : order.indexOf(this.s.next_step);
      const at = order.indexOf(key);
      if (at < current) return "bg-green-50 border-green-200 text-green-800";
      if (at === current) return "bg-indigo-600 border-indigo-600 text-white";
      return "bg-white text-gray-400";
    },

    async upload() {
      if (!confirm(`Upload surah ${this.s.chapter_id} to ${this.s.upload_path}? This writes to the live CDN.`)) return;
      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        body.append("item_ids[]", this.s.id);
        await this.api(this.uploadUrl, { method: "POST", body });
        this.s = await this.api(this.dataUrl);
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    // Downmixes the player to one channel the way a mono speaker does
    // (L+R averaged), so a phase-inverted channel is heard cancelling out.
    applyMono() {
      const el = this.$refs.validateAudio;
      if (!el) return;
      if (!this.mono && !this.monoNodes) return;
      try {
        if (!this.audioCtx) this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        if (!this.monoNodes) {
          const source = this.audioCtx.createMediaElementSource(el);
          const down = this.audioCtx.createGain();
          down.channelCount = 1;
          down.channelCountMode = "explicit";
          down.channelInterpretation = "speakers";
          this.monoNodes = { source, down };
        }
        const { source, down } = this.monoNodes;
        source.disconnect();
        down.disconnect();
        if (this.mono) {
          source.connect(down);
          down.connect(this.audioCtx.destination);
        } else {
          source.connect(this.audioCtx.destination);
        }
        if (this.audioCtx.state === "suspended") this.audioCtx.resume();
      } catch (e) {
        this.error = `Mono playback unavailable: ${e.message}`;
      }
    },

    async runPolarity() {
      this.polarityBusy = true;
      this.error = null;
      try {
        const result = await this.api(this.polarityUrlEndpoint, { method: "POST" });
        this.polarityUrl = result.url;
      } catch (e) {
        this.error = e.message;
      } finally {
        this.polarityBusy = false;
      }
    },

    // The same audio the encoder is handed, without a trimmed file on disk.
    playTrimmed() {
      this.stopTrimmed();
      const audio = new Audio(this.s.audio_url);
      audio.currentTime = this.s.trimmed.start_ms / 1000;
      audio.play().catch((e) => {
        this.error = `Could not play: ${e.message}`;
      });
      this.trimAudio = audio;
      this.trimTimer = setInterval(() => {
        if (!this.trimAudio) return;
        this.trimPlayhead = this.trimAudio.currentTime * 1000 - this.s.trimmed.start_ms;
        if (this.trimAudio.currentTime * 1000 >= this.s.trimmed.end_ms) this.stopTrimmed();
      }, 100);
    },

    stopTrimmed() {
      clearInterval(this.trimTimer);
      this.trimTimer = null;
      if (this.trimAudio) {
        this.trimAudio.pause();
        this.trimAudio = null;
      }
      this.trimPlayhead = 0;
    }
  }
};
</script>

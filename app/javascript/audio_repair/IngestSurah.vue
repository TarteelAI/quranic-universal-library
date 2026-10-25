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
        <a :href="backUrl" class="btn btn-sm btn-outline-secondary">← back to the run</a>
      </div>

      <!-- ===== Original ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">Original</span>
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
          <p v-else class="text-xs text-gray-500">Not downloaded.</p>
        </div>
      </section>

      <!-- ===== Trimmed (virtual) ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">Trimmed</span>
          <span class="text-[11px] text-gray-500">not stored as a file</span>
        </header>
        <div class="p-3">
          <p class="text-[11px] text-amber-800 bg-amber-50 border border-amber-200 rounded p-1.5 mb-2">
            No trimmed file is kept on disk. The cut is applied during the encode, in the same pass, so
            the tree holds only the original and the encoded outputs. What plays here is the original
            between the two cut points — identical audio to what the encoder receives.
          </p>
          <dl class="grid grid-cols-2 md:grid-cols-4 gap-2 text-xs mb-2">
            <div>
              <dt class="text-gray-500">cut from</dt>
              <dd class="font-mono">{{ fmt(s.trimmed.start_ms) }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">cut to</dt>
              <dd class="font-mono">{{ fmt(s.trimmed.end_ms) }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">kept</dt>
              <dd class="font-mono">{{ fmt(s.trimmed.duration_ms) }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">removed</dt>
              <dd class="font-mono">{{ fmt(s.source_duration_ms - s.trimmed.duration_ms) }}</dd>
            </div>
          </dl>
          <div class="flex items-center gap-2">
            <button class="btn btn-sm btn-dark" @click="playTrimmed">▶ play trimmed</button>
            <button class="btn btn-sm btn-outline-secondary" @click="stopTrimmed">■</button>
            <span class="text-xs text-gray-500 font-mono">{{ fmt(trimPlayhead) }}</span>
          </div>
        </div>
      </section>

      <!-- ===== Encoded ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b flex items-baseline justify-between">
          <span class="text-sm font-semibold">Encoded</span>
          <span class="text-[11px] text-gray-500">what ships</span>
        </header>
        <div class="p-3">
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
              <audio :src="s.files[kind].url" controls preload="none" class="w-full h-9"></audio>
              <p class="text-[11px] text-gray-400 mt-1 font-mono break-all">{{ s.files[kind].path }}</p>
            </template>
          </div>
        </div>
      </section>

      <!-- ===== Re-encode ===== -->
      <section class="border rounded mb-3">
        <header class="px-3 py-2 bg-gray-50 border-b">
          <span class="text-sm font-semibold">Re-encode</span>
        </header>
        <div class="p-3 flex items-end gap-3 flex-wrap">
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
          <button class="btn btn-sm btn-dark" :disabled="busy || !s.files.original" @click="reencode">
            {{ busy ? 'Encoding…' : 'Re-encode' }}
          </button>
          <p class="text-[11px] text-gray-500 flex-1 min-w-[240px]">
            Overrides the run's setting ({{ s.ingest_bitrate }}) for this surah only — useful for
            comparing two rates by ear before committing the whole run. Re-encoding rebuilds every
            format from the original, so it is safe to repeat.
          </p>
        </div>
      </section>

      <!-- ===== Checks / polarity ===== -->
      <section class="border rounded">
        <header class="px-3 py-2 bg-gray-50 border-b">
          <span class="text-sm font-semibold">Checks</span>
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
          <p v-else class="text-xs text-gray-500 mb-3">No checks yet — encode the surah first.</p>

          <div class="flex items-center gap-2 flex-wrap">
            <button class="btn btn-sm btn-outline-secondary" :disabled="polarityBusy || !s.files.mp3" @click="runPolarity">
              {{ polarityBusy ? 'Starting…' : 'Full polarity check on the MP3' }}
            </button>
            <a v-if="polarityUrl" :href="polarityUrl" target="_blank" class="text-xs text-indigo-700 underline">
              open the polarity report →
            </a>
            <p class="text-[11px] text-gray-500 flex-1 min-w-[240px]">
              Runs the full timeline analysis in the polarity tool. Only the MP3 is checked: it is the
              file that ships, and the 16k WAV is mono by construction so it has no stereo polarity.
            </p>
          </div>
        </div>
      </section>
    </div>
    <p v-else>Loading…</p>
  </div>
</template>

<script>
export default {
  name: "IngestSurah",
  props: {
    dataUrl: { type: String, required: true },
    reencodeUrl: { type: String, required: true },
    polarityUrlEndpoint: { type: String, required: true },
    backUrl: { type: String, required: true }
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
      pollTimer: null
    };
  },
  computed: {
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
        if (data.status === "encoding") this.poll();
      } catch (e) {
        this.error = e.message;
      }
    },

    poll() {
      clearInterval(this.pollTimer);
      this.pollTimer = setInterval(async () => {
        try {
          const data = await this.api(this.dataUrl);
          this.s = data;
          if (data.status !== "encoding") clearInterval(this.pollTimer);
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

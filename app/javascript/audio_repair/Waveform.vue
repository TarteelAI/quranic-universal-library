<template>
  <div class="waveform">
    <canvas ref="canvas" :width="width" :height="height" class="w-full block rounded bg-gray-50 border" style="height: 46px;"></canvas>
    <div v-if="loading" class="text-[10px] text-gray-400">loading waveform…</div>
  </div>
</template>

<script>
export default {
  props: {
    sessionId: { type: String, required: true },
    chapterAudioFileId: { default: null },
    startMs: { type: Number, required: true },
    endMs: { type: Number, required: true },
    buckets: { type: Number, default: 240 },
    color: { type: String, default: "rgba(37, 99, 235, 0.65)" }
  },

  data() {
    return { peaks: [], loading: false, width: 600, height: 46 };
  },

  watch: {
    startMs() { this.load(); },
    endMs() { this.load(); },
    chapterAudioFileId() { this.load(); }
  },

  mounted() {
    this.load();
  },

  methods: {
    async load() {
      if (!(this.endMs > this.startMs)) { this.peaks = []; this.draw(); return; }
      this.loading = true;
      const q = new URLSearchParams({
        start_ms: Math.round(this.startMs),
        end_ms: Math.round(this.endMs),
        buckets: this.buckets
      });
      if (this.chapterAudioFileId) q.set("chapter_audio_file_id", this.chapterAudioFileId);
      try {
        const res = await fetch(`/audio_repair/sessions/${this.sessionId}/peaks?${q}`);
        const data = await res.json();
        this.peaks = data.peaks || [];
      } catch (e) {
        this.peaks = [];
      } finally {
        this.loading = false;
        this.$nextTick(() => this.draw());
      }
    },

    draw() {
      const canvas = this.$refs.canvas;
      if (!canvas) return;
      const ctx = canvas.getContext("2d");
      const w = canvas.width;
      const h = canvas.height;
      ctx.clearRect(0, 0, w, h);
      if (!this.peaks.length) return;

      const barW = w / this.peaks.length;
      ctx.fillStyle = this.color;
      this.peaks.forEach((p, i) => {
        const barH = Math.max(1, (p / 100) * (h - 2));
        ctx.fillRect(i * barW, (h - barH) / 2, Math.max(1, barW - 1), barH);
      });
    }
  }
};
</script>

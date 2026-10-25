<template>
  <div class="ingest-new">
    <p class="text-sm text-gray-600 mb-3">
      Import a new reciter's surah files from an external site. Give one sample URL and the surah range —
      the number in the file name is substituted for every surah in the range. Metadata is set first because
      the recitation's id decides where the files live (<code>data/audio/&lt;id&gt;</code>).
    </p>

    <form ref="form" :action="createUrl" method="post" class="border rounded p-3">
      <input type="hidden" name="authenticity_token" :value="csrf" />

      <!-- Reciter -->
      <div class="grid md:grid-cols-2 gap-3">
        <div>
          <label class="text-xs text-gray-600 block">
            Reciter
            <Select2
              v-model="reciterId"
              name="reciter_id"
              :options="reciterOptions"
              placeholder="Search reciters…"
            />
          </label>

          <div v-if="reciterId === ''" class="mt-2 pl-3 border-l-2 border-indigo-200">
            <label class="text-xs text-gray-600 block">
              New reciter name <span class="text-red-600">*</span>
              <input
                v-model.trim="newReciterName"
                name="new_reciter_name"
                type="text"
                class="form-control form-control-sm block w-full mt-1"
                placeholder="e.g. Hani ar-Rifai"
              />
            </label>
            <label class="text-xs text-gray-600 block mt-2">
              Bio <span class="text-gray-400">(optional)</span>
              <textarea v-model.trim="reciterBio" name="reciter_bio" rows="2" class="form-control form-control-sm block w-full mt-1"></textarea>
            </label>
          </div>
        </div>

        <div>
          <label class="text-xs text-gray-600 block">
            Recitation name
            <input
              v-model.trim="recitationName"
              name="recitation_name"
              type="text"
              class="form-control form-control-sm block w-full mt-1"
              :placeholder="defaultRecitationName || 'e.g. Hani ar-Rifai — Murattal'"
            />
          </label>
          <label class="text-xs text-gray-600 block mt-2">
            Arabic name <span class="text-gray-400">(optional)</span>
            <input v-model.trim="arabicName" name="arabic_name" type="text" dir="rtl" class="form-control form-control-sm block w-full mt-1" />
          </label>
        </div>
      </div>

      <!-- Style / qirat -->
      <div class="grid md:grid-cols-2 gap-3 mt-3">
        <label class="text-xs text-gray-600 block">
          Recitation style
          <Select2 v-model="styleId" name="recitation_style_id" :options="styleOptions" placeholder="Any style" />
        </label>
        <label class="text-xs text-gray-600 block">
          Qirat <span class="text-gray-400">(leave empty for Hafs)</span>
          <Select2 v-model="qiratId" name="qirat_type_id" :options="qiratOptions" placeholder="Hafs" />
        </label>
      </div>

      <!-- Source -->
      <hr class="my-3" />
      <label class="text-xs text-gray-600 block">
        Sample surah URL <span class="text-red-600">*</span>
        <input
          v-model.trim="sourceUrl"
          name="source_url"
          type="url"
          class="form-control form-control-sm block w-full mt-1 font-mono"
          placeholder="https://example.com/reciter/reciter-001.mp3"
          @input="schedulePreview"
        />
      </label>

      <div class="flex items-end gap-3 flex-wrap mt-3">
        <label class="text-xs text-gray-600">
          From surah
          <input v-model.number="from" name="surah_from" type="number" min="1" max="114" class="form-control form-control-sm w-24 block mt-1" @input="schedulePreview" />
        </label>
        <label class="text-xs text-gray-600">
          To surah
          <input v-model.number="to" name="surah_to" type="number" min="1" max="114" class="form-control form-control-sm w-24 block mt-1" @input="schedulePreview" />
        </label>

        <!-- Only when the file name has more than one number. -->
        <label v-if="tokens.length > 1" class="text-xs text-gray-600">
          Surah number is
          <select v-model.number="tokenIndex" name="token_index" class="form-control form-control-sm block mt-1" @change="schedulePreview">
            <option v-for="t in tokens" :key="t.index" :value="t.index">“{{ t.value }}”</option>
          </select>
        </label>
        <input v-else type="hidden" name="token_index" :value="tokenIndex" />
      </div>

      <!-- Live preview of what will be fetched -->
      <div v-if="preview" class="mt-3 text-xs bg-gray-50 border rounded p-2">
        <div class="font-semibold mb-1">
          {{ preview.count }} file{{ preview.count === 1 ? '' : 's' }} will be downloaded
        </div>
        <div class="font-mono text-[11px] text-gray-700">
          <div>{{ preview.first.chapter_id }} → {{ preview.first.url }}</div>
          <div v-if="preview.count > 1" class="text-gray-400">…</div>
          <div v-if="preview.count > 1">{{ preview.last.chapter_id }} → {{ preview.last.url }}</div>
        </div>
      </div>
      <div v-if="previewError" class="mt-3 text-xs text-red-700 bg-red-50 border border-red-200 rounded p-2">
        {{ previewError }}
      </div>

      <div class="mt-3 flex items-center gap-2">
        <button type="submit" class="btn btn-sm btn-dark" :disabled="!canSubmit" @click.prevent="submit">
          Add audio
        </button>
        <span class="text-xs text-gray-500">
          Creates the reciter and recitation records, then takes you to the download page.
        </span>
      </div>
    </form>
  </div>
</template>

<script>
import Select2 from "./Select2.vue";

export default {
  name: "IngestNew",
  components: { Select2 },
  props: {
    reciters: { type: Array, default: () => [] },
    styles: { type: Array, default: () => [] },
    qiratTypes: { type: Array, default: () => [] },
    previewUrl: { type: String, required: true },
    createUrl: { type: String, required: true },
    csrf: { type: String, default: "" }
  },
  data() {
    return {
      reciterId: "",
      newReciterName: "",
      reciterBio: "",
      recitationName: "",
      arabicName: "",
      styleId: "",
      qiratId: "",
      sourceUrl: "",
      from: 1,
      to: 114,
      tokenIndex: 0,
      tokens: [],
      preview: null,
      previewError: null,
      previewTimer: null
    };
  },
  computed: {
    // Strings: select2 hands back the DOM value and this form submits natively.
    reciterOptions() {
      return [{ value: "", label: "+ New reciter…" }].concat(
        this.reciters.map((r) => ({ value: String(r.id), label: `${r.id} · ${r.name}` }))
      );
    },
    styleOptions() {
      return [{ value: "", label: "—" }].concat(
        this.styles.map((s) => ({ value: String(s.id), label: s.name }))
      );
    },
    qiratOptions() {
      return [{ value: "", label: "—" }].concat(
        this.qiratTypes.map((q) => ({ value: String(q.id), label: q.name }))
      );
    },
    defaultRecitationName() {
      if (this.reciterId === "") return this.newReciterName;
      const found = this.reciters.find((r) => String(r.id) === String(this.reciterId));
      return found ? found.name : "";
    },
    canSubmit() {
      const hasReciter = this.reciterId !== "" || this.newReciterName.length > 0;
      return hasReciter && !!this.preview && !this.previewError;
    }
  },
  methods: {
    // Debounced so typing a URL does not fire a request per keystroke.
    schedulePreview() {
      clearTimeout(this.previewTimer);
      this.previewTimer = setTimeout(this.loadPreview, 400);
    },

    async loadPreview() {
      if (!this.sourceUrl) {
        this.preview = null;
        this.previewError = null;
        return;
      }
      const params = new URLSearchParams({
        source_url: this.sourceUrl,
        surah_from: this.from || 1,
        surah_to: this.to || 114
      });
      // Pin the token only once chosen, so the server's guess can update.
      if (this.tokens.length > 1) params.set("token_index", this.tokenIndex);

      try {
        const res = await fetch(`${this.previewUrl}?${params}`, { headers: { Accept: "application/json" } });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
        this.preview = data;
        this.previewError = null;
        this.tokens = data.tokens || [];
        this.tokenIndex = data.token_index;
      } catch (e) {
        this.preview = null;
        this.previewError = e.message;
      }
    },

    submit() {
      if (!this.canSubmit) return;
      this.$refs.form.submit();
    }
  }
};
</script>

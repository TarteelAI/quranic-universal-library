<template>
  <div class="ingest-progress">
    <div v-if="error" class="text-sm text-red-700 bg-red-50 border border-red-200 rounded p-2 mb-3">
      {{ error }}
    </div>

    <div v-if="state">
      <!-- Summary -->
      <div class="flex items-center justify-between flex-wrap gap-3 mb-3">
        <div class="text-sm">
          <span class="font-semibold">{{ state.recitation.name }}</span>
          <span class="text-gray-400"> · {{ state.recitation.reciter }}</span>
          <div class="text-xs text-gray-500 font-mono mt-1">{{ state.data_dir }}</div>
        </div>
        <div class="flex items-center gap-2">
          <span class="text-xs px-2 py-1 rounded" :class="statusClass">{{ state.status }}</span>
          <button
            v-if="downloading || missingCount > 0"
            class="btn btn-sm btn-dark"
            :disabled="busy || downloading"
            @click="startDownload"
          >
            {{ downloading ? 'Downloading…' : (anyDownloaded ? `Download missing (${missingCount})` : 'Start download') }}
          </button>
          <span v-else class="text-xs text-gray-500">all downloaded</span>
        </div>
      </div>

      <!-- Source URL / range -->
      <div class="border rounded p-2 mb-3">
        <div class="flex items-center justify-between flex-wrap gap-2">
          <div class="text-xs min-w-0">
            <span class="font-semibold">Source</span>
            <span class="text-gray-600 font-mono ml-1 break-all">{{ state.template }}</span>
            <span class="text-gray-400 ml-1">· surahs {{ state.range.from }}–{{ state.range.to }}</span>
          </div>
          <button class="btn btn-sm btn-outline-secondary" @click="toggleSourceEditor">
            {{ editingSource ? 'Cancel' : 'Edit source' }}
          </button>
        </div>

        <div v-if="editingSource" class="mt-2 pt-2 border-t">
          <label class="text-xs text-gray-600 block">
            Sample surah URL
            <input
              v-model.trim="srcUrl"
              type="url"
              class="form-control form-control-sm block w-full mt-1 font-mono"
              @input="scheduleSourcePreview"
            />
          </label>
          <div class="flex items-end gap-3 flex-wrap mt-2">
            <label class="text-xs text-gray-600">
              From surah
              <input v-model.number="srcFrom" type="number" min="1" max="114" class="form-control form-control-sm w-24 block mt-1" @input="scheduleSourcePreview" />
            </label>
            <label class="text-xs text-gray-600">
              To surah
              <input v-model.number="srcTo" type="number" min="1" max="114" class="form-control form-control-sm w-24 block mt-1" @input="scheduleSourcePreview" />
            </label>
            <button class="btn btn-sm btn-dark" :disabled="busy || !srcPreview" @click="saveSource">Save &amp; retry</button>
          </div>

          <div v-if="srcPreview" class="mt-2 text-xs bg-gray-50 border rounded p-2 font-mono text-[11px]">
            <div>{{ srcPreview.first.chapter_id }} → {{ srcPreview.first.url }}</div>
            <div v-if="srcPreview.count > 1">{{ srcPreview.last.chapter_id }} → {{ srcPreview.last.url }}</div>
          </div>
          <div v-if="srcError" class="mt-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded p-2">{{ srcError }}</div>
          <p class="text-[11px] text-amber-800 bg-amber-50 border border-amber-200 rounded p-1.5 mt-2">
            Surahs whose URL changes are reset to pending, and any file they already held is deleted —
            it came from the old address. Surahs whose URL is unchanged keep their downloads.
          </p>
        </div>

        <div v-if="srcSummary" class="mt-2 text-xs text-green-800 bg-green-50 border border-green-200 rounded p-2">
          Updated: {{ srcSummary.reset }} reset, {{ srcSummary.kept }} kept, {{ srcSummary.added }} added,
          {{ srcSummary.removed }} removed<span v-if="srcSummary.discarded_files">, {{ srcSummary.discarded_files }} stale file(s) deleted</span>.
        </div>
      </div>

      <!-- Encoding settings -->
      <div class="flex items-end gap-3 flex-wrap border rounded p-2 mb-3 bg-gray-50">
        <label class="text-xs text-gray-600">
          MP3 bitrate
          <select v-model="bitrate" class="form-control form-control-sm block mt-1" @change="saveSettings">
            <option value="64k">64k</option>
            <option value="96k">96k</option>
            <option value="128k">128k</option>
            <option value="160k">160k</option>
            <option value="192k">192k</option>
            <option value="source">match source</option>
          </select>
        </label>
        <label class="text-xs text-gray-600">
          Downloads at once
          <select v-model.number="concurrency" class="form-control form-control-sm block mt-1" @change="saveSettings">
            <option v-for="n in 6" :key="n" :value="n">{{ n }}</option>
          </select>
        </label>
        <label class="text-xs text-gray-600 flex items-start gap-1.5">
          <input v-model="preTrimmed" type="checkbox" class="mt-0.5" @change="saveSettings" />
          <span>
            Source is already trimmed
            <span class="block text-[11px] text-gray-400">no basmala to remove — skip the review</span>
          </span>
        </label>
        <p class="text-[11px] text-gray-500 flex-1 min-w-[220px]">
          Speech rarely needs more than 128k. Changing this affects surahs encoded from now on —
          re-encode an already-finished surah to apply it.
        </p>
      </div>

      <!-- Overall bar -->
      <div class="mb-1 flex justify-between text-xs text-gray-600">
        <span>{{ doneCount }} of {{ items.length }} downloaded</span>
        <span v-if="failedCount" class="text-red-600">{{ failedCount }} failed</span>
      </div>
      <div class="w-full bg-gray-200 rounded h-2 mb-3 overflow-hidden">
        <div class="bg-indigo-600 h-2 transition-all" :style="{ width: overallPercent + '%' }"></div>
      </div>

      <div v-if="state.last_error" class="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded p-2 mb-3">
        {{ state.last_error }}
      </div>

      <!-- Disk / cleanup -->
      <div class="border rounded p-2 mb-3">
        <div class="flex items-center justify-between flex-wrap gap-2">
          <div class="text-xs">
            <span class="font-semibold">Disk</span>
            <span class="text-gray-600 ml-1">{{ mb(state.disk.total) }} total</span>
            <span v-for="k in cleanKinds" :key="k" class="text-gray-400 ml-2">
              {{ k }} {{ mb(state.disk[k]) }}
            </span>
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <label v-for="k in cleanKinds" :key="'c' + k" class="text-xs flex items-center gap-1">
              <input v-model="cleanup" type="checkbox" :value="k" /> {{ k }}
            </label>
            <button class="btn btn-sm btn-outline-secondary" :disabled="busy || !cleanup.length" @click="runCleanup">
              Delete selected
            </button>
          </div>
        </div>
        <p v-if="cleanup.includes('original')" class="text-[11px] text-amber-800 bg-amber-50 border border-amber-200 rounded p-1.5 mt-2">
          Deleting originals frees the most space, but they are the only copy you have — re-trimming
          or re-encoding at a different bitrate afterwards means downloading those surahs again.
        </p>
      </div>

      <!-- CDN upload -->
      <div class="border rounded p-2 mb-3">
        <div class="flex items-end gap-3 flex-wrap">
          <label class="text-xs text-gray-600 flex-1 min-w-[280px]">
            CDN path
            <input
              v-model.trim="uploadPath"
              type="text"
              class="form-control form-control-sm block w-full mt-1 font-mono"
              placeholder="quran/surah/reciterName/murattal"
              @change="saveUploadPath"
            />
          </label>
          <button
            v-if="encodableSelected.length"
            class="btn btn-sm btn-secondary"
            :disabled="busy"
            @click="encodeSelected"
          >
            Encode {{ encodableSelected.length }} selected
          </button>
          <button
            class="btn btn-sm btn-dark"
            :disabled="busy || uploading || !uploadableSelected.length || !uploadPath"
            @click="uploadSelected"
          >
            {{ uploading ? 'Uploading…' : `Upload ${uploadableSelected.length} selected` }}
          </button>
        </div>
        <p class="text-[11px] text-gray-500 mt-1">
          Each file goes to <span class="font-mono">{{ uploadPath || 'path' }}/&lt;format&gt;/&lt;surah&gt;.&lt;format&gt;</span>
          with its Content-Type set on upload, so browsers play it instead of downloading it.
          This path is also saved as the recitation's relative path.
        </p>
      </div>

      <!-- Status filter -->
      <div class="flex items-center gap-1 flex-wrap mb-2">
        <button
          class="text-xs px-2 py-1 rounded border"
          :class="filter === null ? 'bg-gray-800 text-white border-gray-800' : 'bg-white text-gray-700'"
          @click="filter = null"
        >
          all {{ items.length }}
        </button>
        <button
          v-for="(count, name) in state.status_counts"
          :key="name"
          class="text-xs px-2 py-1 rounded border"
          :class="filter === name ? 'bg-gray-800 text-white border-gray-800' : 'bg-white text-gray-700'"
          @click="filter = filter === name ? null : name"
        >
          {{ name }} {{ count }}
        </button>
      </div>

      <!-- Per-surah -->
      <div class="overflow-x-auto">
        <table class="min-w-full text-sm border">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-3 py-2 w-8">
                <input
                  type="checkbox"
                  :checked="allSelectableChecked"
                  :disabled="!selectableItems.length"
                  title="Select all shown"
                  @change="toggleAll($event)"
                />
              </th>
              <th class="text-left px-3 py-2 w-14">Surah</th>
              <th class="text-left px-3 py-2 w-40">Name</th>
              <th class="text-left px-3 py-2 w-40">Status</th>
              <th class="text-left px-3 py-2">Meta</th>
              <th class="text-left px-3 py-2 w-72">Path on disk</th>
              <th class="px-3 py-2 w-28"></th>
            </tr>
          </thead>
          <tbody>
            <template v-for="item in visibleItems" :key="item.id">
              <tr class="border-t align-top" :class="item.status === 'failed' ? 'bg-red-50' : ''">
                <td class="px-3 py-2">
                  <input
                    v-if="canSelect(item)"
                    type="checkbox"
                    :value="item.id"
                    :checked="selected.includes(item.id)"
                    @change="toggleOne(item.id)"
                  />
                </td>
                <td class="px-3 py-2 font-mono">{{ item.chapter_id }}</td>
                <td class="px-3 py-2">
                  {{ item.name }}
                  <span v-if="!item.expects_head_trim" class="text-[10px] text-gray-400 block">no basmala</span>
                </td>
                <td class="px-3 py-2">
                  <span class="text-xs px-2 py-0.5 rounded" :class="statusBadge(item)">{{ item.display_status }}</span>
                  <div v-if="item.status === 'downloading'" class="w-full bg-gray-200 rounded h-1.5 overflow-hidden mt-1">
                    <div class="h-1.5 bg-indigo-600 transition-all" :style="{ width: item.percent + '%' }"></div>
                  </div>
                </td>
                <td class="px-3 py-2 text-xs">
                  <span v-for="f in item.meta" :key="f.label" class="mr-3 whitespace-nowrap">
                    <span class="text-gray-500">{{ f.label }}</span>
                    <span class="font-mono ml-1">{{ f.value }}</span>
                  </span>
                  <span v-if="!item.meta.length" class="text-gray-300">—</span>
                </td>
                <td class="px-3 py-2 text-[11px] font-mono text-gray-600">
                  <div v-for="p in item.paths" :key="p.path" class="break-all" :class="p.bytes ? '' : 'text-gray-300'">
                    {{ p.path }}
                  </div>
                </td>
                <td class="px-3 py-2 whitespace-nowrap">
                  <button
                    v-if="canProcess(item)"
                    class="btn btn-sm"
                    :class="open === item.id ? 'btn-secondary' : 'btn-primary'"
                    @click="toggle(item)"
                  >
                    {{ open === item.id ? 'Close' : 'Process' }}
                  </button>
                  <button
                    v-else-if="item.status === 'failed'"
                    class="btn btn-sm btn-outline-secondary"
                    :disabled="busy"
                    @click="retry(item)"
                  >
                    retry
                  </button>
                  <a
                    v-if="canProcess(item)"
                    :href="urlFor(surahUrl, item.id)"
                    class="btn btn-sm btn-outline-secondary ml-1"
                    title="Files, metadata, re-encode and polarity"
                  >Files</a>
                </td>
              </tr>
              <tr v-if="open === item.id" :key="'panel' + item.id">
                <td colspan="7" class="px-3 py-3 bg-gray-50">
                  <IngestTrim
                    v-if="detail"
                    :item="detail"
                    :item-url="urlFor(itemUrl, item.id)"
                    :detect-url="urlFor(detectUrl, item.id)"
                    :approve-url="urlFor(approveUrl, item.id)"
                    @close="open = null"
                    @updated="onItemUpdated"
                  />
                  <p v-else class="text-xs text-gray-500">Loading…</p>
                </td>
              </tr>
            </template>
            <tr v-if="!visibleItems.length">
              <td colspan="7" class="px-3 py-4 text-center text-xs text-gray-500">
                No surahs with that status.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <p v-else>Loading…</p>
  </div>
</template>

<script>
import IngestTrim from "./IngestTrim.vue";

export default {
  name: "IngestProgress",
  components: { IngestTrim },
  props: {
    dataUrl: { type: String, required: true },
    downloadUrl: { type: String, required: true },
    retryUrl: { type: String, required: true },
    itemUrl: { type: String, required: true },
    detectUrl: { type: String, required: true },
    approveUrl: { type: String, required: true },
    encodeUrl: { type: String, required: true },
    cleanupUrl: { type: String, required: true },
    settingsUrl: { type: String, required: true },
    surahUrl: { type: String, required: true },
    updateSourceUrl: { type: String, required: true },
    uploadUrl: { type: String, required: true },
    encodeSelectedUrl: { type: String, required: true },
    previewUrl: { type: String, required: true }
  },
  data() {
    return {
      state: null,
      error: null,
      busy: false,
      pollTimer: null,
      open: null,
      detail: null,
      cleanup: [],
      cleanKinds: ["original", "mp3", "opus", "wav"],
      bitrate: "128k",
      concurrency: 3,
      filter: null,
      selected: [],
      uploadPath: "",
      preTrimmed: false,
      editingSource: false,
      srcUrl: "",
      srcFrom: 1,
      srcTo: 114,
      srcPreview: null,
      srcError: null,
      srcSummary: null,
      srcTimer: null
    };
  },
  computed: {
    items() {
      return this.state ? this.state.items : [];
    },
    uploading() {
      return this.state && this.state.status === "uploading";
    },
    selectableItems() {
      return this.visibleItems.filter((i) => this.canSelect(i));
    },
    // The two bulk actions apply to different subsets of one selection, so
    // each button reports only what it can actually act on.
    encodableSelected() {
      return this.items.filter((i) => this.selected.includes(i.id) && this.canEncode(i));
    },
    uploadableSelected() {
      return this.items.filter((i) => this.selected.includes(i.id) && this.canUpload(i));
    },
    allSelectableChecked() {
      return (
        this.selectableItems.length > 0 &&
        this.selectableItems.every((i) => this.selected.includes(i.id))
      );
    },
    visibleItems() {
      if (!this.filter) return this.items;
      return this.items.filter((i) => i.display_status === this.filter);
    },
    doneCount() {
      return this.items.filter((i) => !["pending", "downloading", "failed"].includes(i.status)).length;
    },
    failedCount() {
      return this.items.filter((i) => i.status === "failed").length;
    },
    anyDownloaded() {
      return this.doneCount > 0;
    },
    // Still needs fetching: never downloaded, or failed partway.
    missingCount() {
      return this.items.filter((i) => ["pending", "failed"].includes(i.status)).length;
    },
    downloading() {
      return this.state && this.state.status === "downloading";
    },
    overallPercent() {
      if (!this.items.length) return 0;
      const sum = this.items.reduce((acc, i) => acc + (i.percent || 0), 0);
      return Math.round(sum / this.items.length);
    },
    statusClass() {
      const map = {
        failed: "bg-red-100 text-red-800",
        downloading: "bg-blue-100 text-blue-800",
        downloaded: "bg-green-100 text-green-800",
        verified: "bg-green-100 text-green-800"
      };
      return map[this.state.status] || "bg-gray-100 text-gray-700";
    }
  },
  mounted() {
    this.load();
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    canSelect(item) {
      return !["pending", "downloading"].includes(item.status);
    },

    canEncode(item) {
      return ["downloaded", "trim_proposed", "trim_approved", "encoded", "verified"].includes(item.status);
    },

    async encodeSelected() {
      const ids = this.encodableSelected.map((i) => i.id);
      const skip = this.preTrimmed;
      const note = skip ? " without trimming" : "";
      if (!confirm(`Encode ${ids.length} surah(s)${note}?`)) return;

      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        ids.forEach((id) => body.append("item_ids[]", id));
        if (skip) body.append("skip_trim", "true");
        this.apply(await this.api(this.encodeSelectedUrl, { method: "POST", body }));
        ids.forEach((id) => this.pollItem(id));
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    canUpload(item) {
      return ["encoded", "verified", "uploaded", "uploading"].includes(item.status) && item.encoded_formats.length > 0;
    },

    toggleOne(id) {
      const at = this.selected.indexOf(id);
      if (at === -1) this.selected.push(id);
      else this.selected.splice(at, 1);
    },

    toggleAll(event) {
      const ids = this.selectableItems.map((i) => i.id);
      if (event.target.checked) {
        this.selected = [...new Set(this.selected.concat(ids))];
      } else {
        this.selected = this.selected.filter((id) => !ids.includes(id));
      }
    },

    async saveUploadPath() {
      try {
        const body = new FormData();
        body.append("upload_path", this.uploadPath);
        this.apply(await this.api(this.settingsUrl, { method: "POST", body }));
      } catch (e) {
        this.error = e.message;
      }
    },

    async uploadSelected() {
      if (!confirm(`Upload ${this.selected.length} surah(s) to ${this.uploadPath}? This writes to the live CDN.`)) return;
      this.busy = true;
      this.error = null;
      try {
        const body = new FormData();
        this.selected.forEach((id) => body.append("item_ids[]", id));
        this.apply(await this.api(this.uploadUrl, { method: "POST", body }));
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    statusBadge(item) {
      const map = {
        pending: "bg-gray-100 text-gray-600",
        downloading: "bg-blue-100 text-blue-800",
        downloaded: "bg-sky-100 text-sky-800",
        trimming: "bg-amber-100 text-amber-800",
        trimmed: "bg-amber-100 text-amber-900",
        encoding: "bg-violet-100 text-violet-800",
        encoded: "bg-emerald-100 text-emerald-800",
        validated: "bg-green-100 text-green-800",
        uploading: "bg-blue-100 text-blue-800",
        uploaded: "bg-teal-100 text-teal-800",
        failed: "bg-red-100 text-red-800"
      };
      return map[item.display_status] || "bg-gray-100 text-gray-700";
    },

    urlFor(base, itemId) {
      return `${base}${base.includes("?") ? "&" : "?"}item_id=${itemId}`;
    },

    canProcess(item) {
      return !["pending", "downloading", "failed"].includes(item.status);
    },

    hasChecks(item) {
      return item.checks && Object.keys(item.checks).length > 0;
    },

    checksOk(item) {
      return item.checks && item.checks.channels_ok && item.checks.duration_ok;
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
        this.apply(await this.api(this.dataUrl));
      } catch (e) {
        this.error = e.message;
      }
    },

    apply(state) {
      this.state = state;
      if (state.settings) {
        this.bitrate = state.settings.bitrate;
        this.concurrency = state.settings.concurrency;
        this.preTrimmed = !!state.settings.pre_trimmed;
      }
      if (!this.uploadPath) this.uploadPath = state.upload_path || "";
      if (["downloading", "uploading"].includes(state.status)) this.poll();
      else this.stopPolling();
    },

    toggleSourceEditor() {
      this.editingSource = !this.editingSource;
      this.srcSummary = null;
      if (!this.editingSource) return;
      this.srcUrl = this.state.source_url || "";
      this.srcFrom = this.state.range.from;
      this.srcTo = this.state.range.to;
      this.loadSourcePreview();
    },

    scheduleSourcePreview() {
      clearTimeout(this.srcTimer);
      this.srcTimer = setTimeout(this.loadSourcePreview, 400);
    },

    async loadSourcePreview() {
      if (!this.srcUrl) {
        this.srcPreview = null;
        return;
      }
      const params = new URLSearchParams({
        source_url: this.srcUrl,
        surah_from: this.srcFrom || 1,
        surah_to: this.srcTo || 114
      });
      try {
        const res = await fetch(`${this.previewUrl}?${params}`, { headers: { Accept: "application/json" } });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
        this.srcPreview = data;
        this.srcError = null;
      } catch (e) {
        this.srcPreview = null;
        this.srcError = e.message;
      }
    },

    async saveSource() {
      this.busy = true;
      this.srcError = null;
      try {
        const body = new FormData();
        body.append("source_url", this.srcUrl);
        body.append("surah_from", this.srcFrom);
        body.append("surah_to", this.srcTo);
        const result = await this.api(this.updateSourceUrl, { method: "POST", body });
        this.srcSummary = result.summary;
        this.editingSource = false;
        this.apply(result);
      } catch (e) {
        this.srcError = e.message;
      } finally {
        this.busy = false;
      }
    },

    async saveSettings() {
      try {
        const body = new FormData();
        body.append("bitrate", this.bitrate);
        body.append("concurrency", this.concurrency);
        body.append("pre_trimmed", this.preTrimmed);
        this.apply(await this.api(this.settingsUrl, { method: "POST", body }));
      } catch (e) {
        this.error = e.message;
      }
    },

    async runCleanup() {
      if (!confirm(`Delete ${this.cleanup.join(", ")} files for every surah in this run?`)) return;
      this.busy = true;
      try {
        const body = new FormData();
        this.cleanup.forEach((k) => body.append("kinds[]", k));
        const result = await this.api(this.cleanupUrl, { method: "POST", body });
        this.apply(result);
        this.cleanup = [];
        this.error = result.freed_bytes ? null : "Nothing to delete.";
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    async toggle(item) {
      if (this.open === item.id) {
        this.open = null;
        this.detail = null;
        return;
      }
      this.open = item.id;
      this.detail = null;
      try {
        let data = await this.api(this.urlFor(this.itemUrl, item.id));
        // Detect on first open so the panel is never empty.
        if (!data.trim_detail || !Object.keys(data.trim_detail).length) {
          data = await this.api(this.urlFor(this.detectUrl, item.id), { method: "POST" });
        }
        this.detail = data;
      } catch (e) {
        this.error = e.message;
        this.open = null;
      }
    },

    onItemUpdated(updated) {
      this.detail = updated;
      const row = this.items.find((i) => i.id === updated.id);
      if (row) Object.assign(row, updated);
      if (updated.working) this.pollItem(updated.id);
    },

    pollItem(itemId) {
      const timer = setInterval(async () => {
        try {
          const data = await this.api(this.urlFor(this.itemUrl, itemId));
          const row = this.items.find((i) => i.id === itemId);
          if (row) Object.assign(row, data);
          if (this.open === itemId) this.detail = data;
          // `working` stays true through the check pass, which runs after the
          // status has already moved to "encoded".
          if (!data.working) {
            clearInterval(timer);
            this.load();
          }
        } catch {
          clearInterval(timer);
        }
      }, 2000);
    },

    async startDownload() {
      this.busy = true;
      this.error = null;
      try {
        this.apply(await this.api(this.downloadUrl, { method: "POST" }));
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    async retry(item) {
      this.busy = true;
      try {
        const body = new FormData();
        body.append("item_id", item.id);
        this.apply(await this.api(this.retryUrl, { method: "POST", body }));
        this.poll();
      } catch (e) {
        this.error = e.message;
      } finally {
        this.busy = false;
      }
    },

    poll() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(async () => {
        try {
          const s = await this.api(this.dataUrl);
          this.state = s;
          if (!["downloading", "uploading"].includes(s.status)) this.stopPolling();
        } catch (e) {
          this.stopPolling();
          this.error = e.message;
        }
      }, 1500);
    },

    stopPolling() {
      if (this.pollTimer) clearInterval(this.pollTimer);
      this.pollTimer = null;
    },

    mb(bytes) {
      if (!bytes) return "—";
      const gb = bytes / 1073741824;
      return gb >= 1 ? `${gb.toFixed(2)} GB` : `${(bytes / 1048576).toFixed(1)} MB`;
    },

    durationLabel(ms) {
      if (!ms) return "—";
      const total = Math.round(ms / 1000);
      const m = Math.floor(total / 60);
      const s = total % 60;
      return `${m}:${String(s).padStart(2, "0")}`;
    }
  }
};
</script>

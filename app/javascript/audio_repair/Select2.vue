<template>
  <select
    ref="el"
    :name="name"
    :class="selectClass"
    :value="modelValue"
    @change="onNativeChange"
  >
    <option v-for="o in options" :key="String(o.value)" :value="o.value">{{ o.label }}</option>
  </select>
</template>

<script>
// select2 is deliberately NOT imported. The application bundle already
// registers it on window.jQuery, and both bundles are deferred so it runs
// first. Importing it again would bundle a second jQuery and register select2
// on that private instance, so the search box would silently never appear.
function ensureSelect2() {
  const jq = window.jQuery;
  return jq && jq.fn && jq.fn.select2 ? jq : null;
}

export default {
  name: "Select2",
  props: {
    modelValue: { type: [String, Number], default: "" },
    // [{ value, label }] — values must be strings for native form submission.
    options: { type: Array, required: true },
    name: { type: String, default: null },
    placeholder: { type: String, default: "Search…" },
    selectClass: { type: String, default: "form-control form-control-sm block w-full mt-1" },
    // A six-item list does not need a search box; a reciter list does.
    minimumResultsForSearch: { type: Number, default: 8 }
  },
  emits: ["update:modelValue"],
  data() {
    return { jq: null };
  },
  watch: {
    // Keeps select2's rendered label in step with external value changes.
    modelValue(value) {
      const el = this.$refs.el;
      if (!el || el.value === String(value)) return;
      el.value = value;
      if (this.jq) this.jq.trigger("change.select2");
    },
    options() {
      if (!this.jq) return;
      this.$nextTick(() => {
        this.jq.trigger("change.select2");
      });
    }
  },
  mounted() {
    this.$nextTick(this.init);
  },
  beforeUnmount() {
    this.destroy();
  },
  methods: {
    init() {
      const jq = ensureSelect2();
      const el = this.$refs.el;
      // Without jQuery/select2 the plain <select> still works and submits.
      if (!jq || !el) return;

      try {
        this.jq = jq(el);
        this.jq.select2({
          width: "100%",
          placeholder: this.placeholder,
          minimumResultsForSearch: this.minimumResultsForSearch
        });
        // select2 suppresses the native change event, so bridge its own back
        // into Vue.
        this.jq.on("select2:select select2:clear", () => {
          this.$emit("update:modelValue", el.value);
        });
      } catch (e) {
        this.jq = null;
      }
    },

    destroy() {
      if (!this.jq) return;
      try {
        const instance = this.jq.data("select2");
        if (instance) instance.destroy();
      } catch (e) {
        /* already gone */
      }
      this.jq = null;
    },

    onNativeChange(event) {
      this.$emit("update:modelValue", event.target.value);
    }
  }
};
</script>

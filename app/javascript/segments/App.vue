<template>
  <div class="space-y-3 pb-20">
    <div
        v-if="showMobileWarning"
        class="md:hidden flex items-start justify-between gap-3 p-3 bg-amber-50 border border-amber-300 text-amber-800 rounded-lg text-sm"
    >
      <span>This tool works best on a larger screen. Some controls may be hard to use on a small screen.</span>
      <button @click="showMobileWarning = false" class="text-amber-700 hover:text-amber-900 text-xl leading-none">×</button>
    </div>

    <Alert />
    <SelectAudioSrc />
    <ActionBar />
    <Verse />

    <div
        v-if="isLoading"
        class="fixed bottom-4 right-4 z-[200] flex items-center gap-2 px-4 py-2 bg-gray-900/90 text-white text-sm rounded-full shadow-lg pointer-events-none"
    >
      <span class="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
      {{ loadingText }}
    </div>
  </div>
</template>

<script>
// copied from https://github.com/vuejs/vuex/blob/4.0/examples/composition/shopping-cart/components/ProductList.vue
import { mapState } from "vuex";
import { useStore } from "vuex";
import SelectAudioSrc from "./components/SelectAudioSrc.vue";
import Alert from "./components/Alert.vue";
import ActionBar from "./components/ActionBar.vue";
import Verse from "./components/Verse.vue";

export default {
  name: "App",
  data() {
    return {
      showMobileWarning: true,
    };
  },
  computed: {
    ...mapState(["loadingSegments", "loadingLetters"]),
    isLoading() {
      return this.loadingSegments || this.loadingLetters;
    },
    loadingText() {
      return this.loadingSegments ? "Loading segments…" : "Loading letters…";
    },
  },
  mounted() {
    const {
      recitation,
      chapter,
      verse,
      versesCount,
      compareSegment,
      audioType,
      segmentLocked,
      segmentsUrl,
      autoPlay,
      compare,
      recitationsList,
    } =
      this.$el.parentElement.dataset;
    const store = useStore();

    store.commit("SETUP", {
      recitation,
      chapter,
      verse,
      versesCount,
      compareSegment,
      audioType,
      segmentLocked,
      segmentsUrl,
      autoPlay,
      compareParam: compare,
      recitationsList,
    });

    store.dispatch("LOAD_SEGMENTS", {});
  },
  components: {
    SelectAudioSrc,
    Alert,
    ActionBar,
    Verse,
  }
};
</script>

<style>
.form-control-xs {
  padding: 0;
  width: 90px;
}
</style>

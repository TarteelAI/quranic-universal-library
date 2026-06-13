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
  </div>
</template>

<script>
// copied from https://github.com/vuejs/vuex/blob/4.0/examples/composition/shopping-cart/components/ProductList.vue
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

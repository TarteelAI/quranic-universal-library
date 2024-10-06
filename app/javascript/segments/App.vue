<template>
  <div>
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
      autoPlay
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

<template>
  <div>
    <Alert />
    <SelectSVG />
    <ActionBar />
    <PointsPreview />
  </div>
</template>

<script>
import Alert from "./components/Alert.vue";
import SelectSVG from "./components/SelectSVG.vue";
import ActionBar from "./components/ActionBar.vue";
import PointsPreview from "./components/PointsPreview.vue"

export default {
  name: "SVG",
  mounted() {
    this.$store.commit("SET_ALERT", {
      text: "Select the SVG to get started."
    });  },
  components: {
    SelectSVG,
    Alert,
    ActionBar,
    PointsPreview
  },
};
</script>
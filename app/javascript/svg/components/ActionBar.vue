<template>
  <div class="row my-2">
    <div class="col-12 my-2 d-flex justify-content-center align-items-center" v-if="!!file">
        <span class="me-2">
          Point every x length(max 30)
        </span>
      <input type="number" min="0" max="30" class="input-xs" :value="stepSize" @change="updateStepSize"/>
      <button
          class="btn btn-success btn-xs mx-1"
          @click="generatePoints"
      >
        Generate Points
      </button>
      <button
          class="btn btn-success btn-xs mx-1"
          @click="merge"
      >
        Merge Base Path
      </button>

      <button
          class="btn btn-info btn-xs mx-1"
          @click="optimize"
      >
        Optimize Path
      </button>
      <button
          class="btn btn-info btn-xs mx-1"
          @click="optimize"
      >
        Path Info
      </button>
      <button
          class="btn btn-info btn-xs mx-1"
          @click="saveFile"
      >
        Save
      </button>
    </div>
  </div>
</template>

<script>
import {mapState} from "vuex";

export default {
  name: "ActionBar",
  data() {
  },
  mounted() {
  },
  computed: {
    ...mapState([
      "file",
      "stepSize"
    ])
  },
  methods: {
    generatePoints(event) {
      this.$store.dispatch('GENERATE_POINTS');
    },
    merge(event){
      this.$store.dispatch('MERGE_BASE_PATH')
    },
    updateStepSize(event){
      const size = Number(event.target.value);
      if(size > 0){
        this.$store.commit("SET_STEP_SIZE", {
          size: size
        });
      }
    },
    optimize(event) {
    },
    toSvg() {

    },
    info() {

    },
    saveFile() {

    }
  },
};
</script>

<style>
.input-xs {
  padding: 0;
  width: 90px;
}
</style>

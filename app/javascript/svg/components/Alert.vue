<template>
</template>

<script>
import { mapState } from 'vuex'

export default {
  name: 'Alert',
  created(){
    this.unwatchAlert = this.$store.watch(
        (state, getters) => state.alert,
        (text, _) => {
          if(text){
            this.$toast.info(text);
          } else{
            this.$toast.clear()
          }
        },
    );
  },
  beforeDestroy() {
    this.unwatchAlert ();
  },
  computed: {
    ...mapState([
     'alert'
   ])
  }
}
</script>

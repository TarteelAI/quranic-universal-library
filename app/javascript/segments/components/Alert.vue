<template>
</template>

<script>
import { mapState } from 'vuex'
import toastr from "toastr";
toastr.options = {
  closeButton: true,
  debug: false,
  newestOnTop: true,
  progressBar: true,
  positionClass: "toast-top-right",
  preventDuplicates: true,
  onclick: null,
  showDuration: 300,
  hideDuration: 100,
  timeOut: 1000,
  extendedTimeOut: 0,
  showEasing: "swing",
  hideEasing: "linear",
  showMethod: "fadeIn",
  hideMethod: "fadeOut",
  tapToDismiss: true
};

export default {
  name: 'Alert',
  created(){
    this.unwatchAlert = this.$store.watch(
        (state, getters) => state.alert,

        (text, _) => {
          if(text){
            toastr.info(text);
          } else{
            toastr.clear();
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

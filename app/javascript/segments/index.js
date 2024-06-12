import { createApp } from "vue";
import store from "./store";
import Toaster from "@meforma/vue-toaster";

import App from "./App.vue";

const app = createApp(App);
app.use(store);
app.use(Toaster, {
    // One of the options
    position: "top-right",
});

app.mount("#app");

import { createApp } from 'vue';
import { createPinia } from 'pinia';
import Toast from 'vue-toastification';
import 'vue-toastification/dist/index.css';
import App from './App.vue';

const pinia = createPinia();

const app = createApp(App);

// Configure toast notifications
app.use(Toast, {
  transition: 'Vue-Toastification__bounce',
  maxToasts: 3,
  newestOnTop: true,
  position: 'top-right',
  timeout: 4000,
  closeOnClick: true,
  pauseOnFocusLoss: true,
  pauseOnHover: true,
  draggable: true,
  draggablePercent: 0.6,
  showCloseButtonOnHover: false,
  hideProgressBar: false,
  icon: true,
  rtl: false
});

app.use(pinia);

app.mount('#app');

app.config.errorHandler = (err, vm, info) => {
  console.error('Global error:', err);
  app.config.globalProperties.$toast.error('An unexpected error occurred');
};
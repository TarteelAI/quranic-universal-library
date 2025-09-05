import "./libs/jquery";
import "./active_admin/base";
import "./active_admin/searchable_select";
import "chartkick/chart.js";

import "@hotwired/turbo-rails";
import "./controllers/for_admin";

document.addEventListener("turbo:load", () => {
  // Tooltip functionality removed - Bootstrap dependency eliminated
});

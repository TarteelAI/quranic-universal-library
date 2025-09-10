import "./libs/jquery";
import "./active_admin/base";
import './active_admin/searchable_select'
import "chartkick/chart.js"

import "@hotwired/turbo-rails";
import "./controllers/for_admin";

// Bootstrap tooltip removed - using custom Stimulus tooltip controller instead

document.addEventListener("turbo:load", () =>{
  setTimeout(()=>{
    $("[title]").tooltip()
  }, 1000)
})
import "./libs/jquery";
import "./active_admin/base";
import './active_admin/searchable_select'
import "chartkick/chart.js"

import "@hotwired/turbo-rails";
import "./controllers/for_admin";

require("bootstrap/js/dist/tooltip")

document.addEventListener("turbo:load", () =>{
  setTimeout(()=>{
    $("[title]").tooltip()
  }, 1000)
})
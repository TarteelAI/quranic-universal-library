import "./libs/jquery";
import "./active_admin/base";
import "./active_admin/searchable_select";
import "chartkick/chart.js";

import "@hotwired/turbo-rails";
import "./controllers/for_admin";

document.addEventListener("turbo:load", () => {
  setTimeout(() => {
    const elementsWithTitle = document.querySelectorAll("[title]:not([data-controller*='tooltip'])");
    elementsWithTitle.forEach(element => {
      if (!element.hasAttribute('data-controller')) {
        element.setAttribute('data-controller', 'tooltip');
      } else {
        const controllers = element.getAttribute('data-controller').split(' ');
        if (!controllers.includes('tooltip')) {
          element.setAttribute('data-controller', controllers.join(' ') + ' tooltip');
        }
      }
    });
  }, 1000);
});

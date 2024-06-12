// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import {Controller} from "@hotwired/stimulus";
import {loadJavascript} from "../utils/script_loader";

export default class extends Controller {
  connect() {
    this.loadLib()
    this.confirmGraph();
  }

  disconnect() {
  }

  loadLib() {
    loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/peity/3.3.0/jquery.peity.min.js").then(this.generateGraph.bind(this))
  }

  confirmGraph() {
    let element = $(this.element);

    setTimeout(() => {
      // if text area is still visible, means editor didn't initialized
      if (element.is(":visible")) {
        this.loadLib();
      }
    }, 300);
  }


  generateGraph() {
    if(!this.el){
      this.el = $(this.element)
      this.el.peity(this.el.data('chart'), {
       width: '100%',
       height: 100
      })
    }
  }
}

import { Controller } from "@hotwired/stimulus";

const BODY_CLASSES = []

export default class extends Controller {
  connect() {
    const {title, body_class} = this.element.dataset;
    BODY_CLASSES.forEach((klass, i) => {
      body.classList.remove(klass)
    })

     if(body_class){
       body.classList.add(body_class)
       BODY_CLASSES.push(body_class)
     }

    document.title = title
  }
}

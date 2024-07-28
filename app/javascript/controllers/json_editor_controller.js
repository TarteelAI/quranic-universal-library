// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import { Controller } from "@hotwired/stimulus"
//import '@json-editor/json-editor';
import {loadJavascript, loadStylesheet} from "../utils/script_loader";

export default class extends Controller {
  connect() {
    loadStylesheet("https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.10.2/jsoneditor.css");
    loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.10.2/jsoneditor.min.js").then(this.initEditor.bind(this))
  }

  initEditor(){
    let el = $(this.element)
    el.hide();

    const editorDiv = document.createElement('div');
    editorDiv.id="json-editor-form"
    this.element.parentNode.insertBefore(editorDiv, this.element);

    const config = {
      modes: ['code', 'form', 'text', 'tree', 'view', 'preview'], // allowed modes
      onChange: () => {
        el.val(JSON.stringify(this.editor.get()))
      }
    }
    this.editor = new JSONEditor(document.getElementById('json-editor-form'), config);
    this.editor.set(this.initialJson())

    el.val(JSON.stringify(this.editor.get()))
  }

  initialJson() {
    return JSON.parse(this.element.dataset.json || "{}")
  }


  disconnect() {
    if(this.editor)
    this.editor.destroy();
  }
}

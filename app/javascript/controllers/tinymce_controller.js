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

const cleanHtml = (html) => {
  let dom = $(`<div>`).html(html)
  dom[0].querySelectorAll("span, p, div")
    .forEach(el => el.textContent.trim() === "" && el.parentNode.removeChild(el));

  return dom.html()
}

export default class extends Controller {
  connect() {
    this.loadEditor()

    let form = $(this.element).closest('form');
    form.on('submit', (e) => {
      const value = this.element.value;

      if (value)
        this.element.value = cleanHtml(value)
    })

    this.confirmEditor();
  }

  disconnect() {
    if (typeof tinyMCE == "object") {
      const active = tinymce.activeEditor;
      if (active)
        active.destroy()
    }
  }

  loadEditor() {
    if (typeof tinyMCE == "object") {
      this.createEditor();
    } else {
      loadJavascript("https://cdnjs.cloudflare.com/ajax/libs/tinymce/5.4.1/tinymce.min.js").then(this.createEditor.bind(this))
    }
  }

  confirmEditor() {
    let element = $(this.element);

    setTimeout(() => {
      // if text area is still visible, means editor didn't initialized
      if (element.is(":visible")) {
        this.loadEditor();
      }
    }, 300);
  }


  createEditor() {
    const {stylesheet} = this.element.dataset;
    const styles = [document.querySelector('#tinymce_custom_style').href];

    if (stylesheet)
      styles.push(stylesheet)

    tinymce.init({
      selector: `#${this.element.id}`,
      height: 500,
      convert_urls: false,
      menubar: true,
      forced_root_block: false,
      entity_encoding: "raw",
      force_p_newlines: true,
      content_css: styles,
      setup: (editor) => {
        editor.on("selectionchange", () => {
          var selectedText = editor.selection.getContent({format: "text"});

          // Check if text is selected
          if (selectedText.length > 0) {
           // this.showPopup(selectedText, editor.selection);
          } else {
            // Hide the popup if no text is selected
           // this.hidePopup();
          }
        });

        editor.ui.registry.addButton("popupButton", {
          icon: "paste-text",
          onAction: () => {
            // Custom logic to display the popup when the button is clicked
            // You can use the editor.selection API to get the selected text
            var selectedText = editor.selection.getContent({format: "text"});
            this.showPopup(selectedText, editor.selection);
          },
        })
      },
      plugins: [
        "advlist lists link image charmap print preview anchor",
        "searchreplace visualblocks fullscreen",
        "insertdatetime media table paste code help wordcount selection"
      ],
      toolbar:
        "undo redo | formatselect | " +
        " bold italic backcolor | alignleft aligncenter " +
        " alignright alignjustify | bullist numlist outdent indent | " +
        " removeformat | popupButton | help"
    });
  }

  hidePopup() {

  }

  showPopup(selectedText, selection) {
    $(".suggestion-popup").remove();

    var popup = document.createElement("div");
    popup.className = "suggestion-popup";
    popup.innerHTML = this.suggestionPopupTemplate(selectedText);

    var selectedRange = selection.getRng();
    /* var boundingRect = selectedRange.getBoundingClientRect();
     popup.style.top = boundingRect.bottom + "px";
     popup.style.left = boundingRect.left + "px";
 */
    // Append the popup to the body
    document.body.appendChild(popup);

    // Close the popup when clicking outside of it
    document.addEventListener("click", function (event) {
      if (!popup.contains(event.target)) {
        document.body.removeChild(popup);
      }
    });
  }

  suggestionPopupTemplate(text) {
    return `
<div class="suggestion-panel" data-controller="search-suggestion">
 <div class="header">
 <span>Search suggestion</span>
  <button class="close">x</button>
 </div>

<div class="suggestions">
<section>
  
</section>
</div>

<div class="search-wrapper">
  <textarea>${text}</textarea>
</div>
</div>`
  }
}

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

// Highlight colours a tafsir can use. Each one is a class styled under
// `.tafsir` in shared/content.scss, keep the colours here in sync with it.
const TAFSIR_HIGHLIGHTS = [
  {name: "red", label: "Red", color: "#950000"},
  {name: "blue", label: "Blue", color: "#006d98"},
  {name: "green", label: "Green", color: "#008000"},
  {name: "hlt", label: "Light green", color: "#57D798"},
  {name: "brown", label: "Brown", color: "#707070"},
  {name: "gray", label: "Gray", color: "#999999"},
  {name: "reference", label: "Reference (small, pink)", color: "#FF0066"},
];

const highlightFormat = (name) => `highlight_${name}`;

// A quote that fills its whole paragraph is saved without the paragraph:
// <p class="ar qpc-hafs"><quran-text>…</quran-text></p> is saved as
// <quran-text data-display="block">…</quran-text>, shown as a paragraph
// (see shared/content.scss).
//
// TinyMCE wraps anything inline at the top level in a <p> (force_p_newlines),
// so while editing such a quote sits in a <p data-quote dir="rtl">, which is
// dropped again when the text is saved. See addQuoteParagraphs.
const QUOTE_TAGS = ["quran-text", "hadith-text"];

// The paragraph's language and font classes don't apply to the quote,
// anything else (a colour...) moves onto it. Same as QuranQuote::Tagger.
const PARAGRAPH_CLASSES = ["ar", "arabic", "qpc-hafs"];

const markQuoteParagraph = (editor, element) => {
  const parent = element.parentNode;

  if (parent && parent !== editor.getBody() && ["P", "DIV"].includes(parent.nodeName) &&
    parent.textContent.trim() === element.textContent.trim()) {
    const paragraph = parent.nodeName === "P" ? parent : editor.dom.rename(parent, "p");
    const lang = paragraph.getAttribute("lang");

    [...paragraph.classList]
      .filter((name) => !PARAGRAPH_CLASSES.includes(name) && name !== lang)
      .forEach((name) => element.classList.add(name));
    [...paragraph.attributes].forEach(({name}) => paragraph.removeAttribute(name));
    editor.dom.setAttribs(paragraph, {"data-quote": "1", dir: "rtl"});
    element.setAttribute("data-display", "block");
  }
};

// Wraps the selection in a quote tag and returns the new tags. After the
// format is applied the selection can be the paragraph around the tag, so
// they're found by comparing with the tags that were there before.
const applyQuote = (editor, tag) => {
  const before = new Set(editor.dom.select(tag));
  editor.formatter.apply(tag.replace("-", "_"));

  const added = editor.dom.select(tag).filter((element) => !before.has(element));
  added.forEach((element) => markQuoteParagraph(editor, element));
  return added;
};

// Scripts a <quran-text> tag can be drawn in, as its data-script. No
// data-script means QPC Hafs. The fonts are set in shared/content.scss.
const QURAN_SCRIPTS = [
  {value: "", label: "QPC Hafs"},
  {value: "dk", label: "Digital Khatt"},
];

const swatchIcon = (color) =>
  `<svg width="24" height="24"><rect x="5" y="5" width="14" height="14" rx="2" fill="${color}"/></svg>`;

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
    if (tinymce.get(this.element.id)) return

    // bodyClass lets a page reuse its preview styles in the editor, e.g. the
    // tafsir highlight colors are all scoped under `.tafsir`
    const {stylesheet, bodyClass, highlights, quranTextUrl, hadithText} = this.element.dataset;
    const highlightColors = highlights === "tafsir" ? TAFSIR_HIGHLIGHTS : [];
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
      body_class: bodyClass || "",
      // Quran fonts to try on Arabic text, the @font-faces come from
      // shared/font_faces.scss (loaded through tinymce_custom)
      font_formats: "QPC Hafs=qpc-hafs; Digital Khatt=digitalkhatt-v2; Digital Khatt V1=digitalkhatt; Digital Khatt IndoPak=digitalkhatt-indopak",
      // <quran-text> holds a Quran quote (see QuranQuote::Tagger), <hadith-text>
      // a hadith. "~" makes them inline elements like span.
      custom_elements: "~quran-text,~hadith-text",
      extended_valid_elements: "quran-text[data-from|data-to|data-script|data-display|class|lang|dir],hadith-text[data-display|class|lang|dir],p[class|lang|dir|style|data-quote]",
      formats: {
        ...Object.fromEntries(highlightColors.map(({name}) => [
          highlightFormat(name), {inline: "span", classes: name, exact: true}
        ])),
        quran_text: {inline: "quran-text"},
        hadith_text: {inline: "hadith-text"},
      },
      setup: (editor) => {
        if (highlightColors.length) this.addHighlightMenu(editor, highlightColors);
        if (quranTextUrl) this.addQuranTextMenu(editor, quranTextUrl);
        if (hadithText) this.addHadithTextButton(editor);
        this.addQuoteParagraphs(editor);
      },
      plugins: [
        "advlist lists link image charmap print preview anchor",
        "searchreplace visualblocks fullscreen",
        "insertdatetime media table paste code help wordcount selection"
      ],
      toolbar:
        "undo redo | formatselect fontselect | " +
        ` bold italic ${highlightColors.length ? "highlight" : "backcolor"} ${quranTextUrl ? "quranText" : ""} ${hadithText ? "hadithText" : ""} | alignleft aligncenter ` +
        " alignright alignjustify | bullist numlist outdent indent | " +
        " removeformat | help"
    });
  }

  // A "Highlight" toolbar menu that wraps the selection in one of the
  // highlight classes, or strips them. Classes instead of the stock colour
  // picker, so the text keeps the colours the tafsir is styled with.
  addHighlightMenu(editor, colors) {
    const removeAll = () => colors.forEach(({name}) => editor.formatter.remove(highlightFormat(name)));

    colors.forEach(({name, color}) => editor.ui.registry.addIcon(`highlight-${name}`, swatchIcon(color)));

    editor.ui.registry.addMenuButton("highlight", {
      icon: "highlight-bg-color",
      tooltip: "Highlight selected text",
      fetch: (callback) => {
        const items = colors.map(({name, label}) => ({
          type: "togglemenuitem",
          text: label,
          icon: `highlight-${name}`,
          active: editor.formatter.match(highlightFormat(name)),
          onAction: () => {
            editor.undoManager.transact(() => {
              // one colour at a time, swap instead of nesting spans
              removeAll();
              editor.formatter.apply(highlightFormat(name));
            });
          }
        }));

        items.push({type: "separator"}, {
          type: "menuitem",
          text: "Remove highlight",
          icon: "remove-formatting",
          onAction: () => editor.undoManager.transact(removeAll)
        });

        callback(items);
      }
    });
  }

  // A "Quran" toolbar menu. With text selected it wraps it in <quran-text>
  // in the script picked, and asks the server where in the Quran it is
  // (data-from and data-to). Inside a tag it changes the script, looks the
  // ayahs up again, or removes the tag.
  addQuranTextMenu(editor, url) {
    const current = () => editor.dom.getParent(editor.selection.getNode(), "quran-text");
    const notify = (text, type = "info") => editor.notificationManager.open({text, type, timeout: 5000});

    const locate = (element) => {
      const form = this.element.closest("form");
      const text = element.textContent;
      const body = new FormData();
      body.append("text", text);
      ["start_verse_id", "end_verse_id"].forEach((name) => {
        const value = form?.querySelector(`[name="tafsir[${name}]"]`)?.value;
        if (value) body.append(name, value);
      });

      fetch(url, {
        method: "POST",
        body,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "",
        },
      })
        .then((response) => response.ok ? response.json() : Promise.reject(response.status))
        .then((result) => {
          // the quote was edited or removed while this was looked up
          if (!editor.getBody().contains(element) || element.textContent !== text) return;

          editor.undoManager.transact(() => {
            if (result.from) {
              editor.dom.setAttribs(element, {"data-from": result.from, "data-to": result.to});
            } else {
              editor.dom.setAttribs(element, {"data-from": null, "data-to": null});
            }
          });
          editor.nodeChanged();

          if (!result.words) {
            notify("Couldn't find this text in the Quran. It's tagged as Quran text, without the ayahs.", "warning");
          } else if (!result.from) {
            notify("These words are in more than one place in the Quran. Set data-from and data-to in Source code.", "warning");
          } else if (result.words < result.total) {
            notify(`Only the first ${result.words} of ${result.total} words match ${result.from} – ${result.to}. Check the selection.`, "warning");
          } else {
            notify(`Found ${result.from} – ${result.to}`, "success");
          }
        })
        .catch(() => notify("Couldn't look up the ayahs, try again.", "error"));
    };

    const mark = (script) => {
      if (editor.selection.isCollapsed()) {
        notify("Select the Quran text first.", "warning");
        return;
      }

      let elements = [];
      editor.undoManager.transact(() => {
        elements = applyQuote(editor, "quran-text");
        // merged into a quote next to it
        if (!elements.length && current()) elements = [current()];
        if (script) elements.forEach((element) => element.setAttribute("data-script", script));
      });

      elements.forEach(locate);
    };

    editor.ui.registry.addMenuButton("quranText", {
      text: "Quran",
      tooltip: "Mark Quran text",
      fetch: (callback) => {
        const element = current();

        if (!element) {
          callback(QURAN_SCRIPTS.map(({value, label}) => ({
            type: "menuitem",
            text: `Mark as Quran (${label})`,
            onAction: () => mark(value),
          })));
          return;
        }

        const script = element.getAttribute("data-script") || "";
        callback([
          ...QURAN_SCRIPTS.map(({value, label}) => ({
            type: "togglemenuitem",
            text: label,
            active: script === value,
            onAction: () => editor.undoManager.transact(() => {
              editor.dom.setAttrib(element, "data-script", value || null);
              editor.nodeChanged();
            }),
          })),
          {type: "separator"},
          {type: "menuitem", text: "Find the ayahs again", onAction: () => locate(element)},
          {
            type: "menuitem",
            text: "Remove Quran tag",
            icon: "remove-formatting",
            onAction: () => editor.undoManager.transact(() => editor.dom.remove(element, true)),
          },
        ]);
      },
    });
  }

  // Quotes standing on their own, outside a paragraph, get a <p data-quote>
  // while they're edited and lose it again when saved
  addQuoteParagraphs(editor) {
    const isQuote = (node) => node && QUOTE_TAGS.includes(node.name);
    const isBlank = (node) => node.type === 3 && !node.value.trim();

    editor.on("PreInit", () => {
      editor.parser.addNodeFilter(QUOTE_TAGS.join(","), (nodes) => nodes.forEach((node) => {
        if (node.attr("data-display") === "block" && node.parent && !node.parent.parent) {
          const paragraph = new tinymce.html.Node("p", 1);
          paragraph.attr({"data-quote": "1", dir: "rtl"});
          node.wrap(paragraph);
        }
      }));

      editor.serializer.addNodeFilter("p", (nodes) => nodes.forEach((paragraph) => {
        if (!paragraph.attr("data-quote")) return;

        const children = [];
        for (let child = paragraph.firstChild; child; child = child.next) {
          if (!isBlank(child)) children.push(child);
        }

        if (children.length === 1 && isQuote(children[0])) {
          children[0].attr("data-display", "block");
          paragraph.unwrap();
        } else {
          // more text was typed in, keep it as a normal paragraph
          paragraph.attr({"data-quote": null, dir: null});
          children.filter(isQuote).forEach((quote) => quote.attr("data-display", null));
        }
      }));
    });
  }

  // A "Hadith" toggle: wraps the selection in <hadith-text>, or removes the
  // tag when the cursor is in one
  addHadithTextButton(editor) {
    const current = () => editor.dom.getParent(editor.selection.getNode(), "hadith-text");

    editor.ui.registry.addToggleButton("hadithText", {
      text: "Hadith",
      tooltip: "Mark hadith text",
      onAction: () => {
        const element = current();

        if (element) {
          editor.undoManager.transact(() => editor.dom.remove(element, true));
        } else if (editor.selection.isCollapsed()) {
          editor.notificationManager.open({text: "Select the hadith text first.", type: "warning", timeout: 5000});
        } else {
          editor.undoManager.transact(() => applyQuote(editor, "hadith-text"));
        }
        editor.nodeChanged();
      },
      onSetup: (api) => {
        const update = () => api.setActive(!!current());
        editor.on("NodeChange", update);
        return () => editor.off("NodeChange", update);
      },
    });
  }
}

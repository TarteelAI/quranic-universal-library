import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    this.defaults = {
      syntaxGraphTokenFontSize: 34,
      syntaxGraphTagFontSize: 15,
      syntaxGraphHeaderFontSize: 10,
      syntaxGraphElidedWordFontSize: 22,
      syntaxGraphEdgeLabelFontSize: 15,
      syntaxGraphHeaderTextDeltaY: 15,
      syntaxGraphPosTagGap: 25,
      syntaxGraphBracketDeltaY: 16,
      syntaxGraphWordGap: 63,
      syntaxGraphHeaderExtraGap: 10,
      syntaxGraphPosTagYOffset: 65,
      defaultFont: "Helvetica Neue, Arial, sans-serif",
      defaultArabicFont: "qpc-hafs",
      elidedWordFont: "Arial, sans-serif",
    };

    this.loadFromUrl();
    this.setupModal();
  }

  setupModal() {
    this.escapeHandler = (e) => {
      if (e.key === "Escape" && !this.modalTarget.classList.contains("tw-hidden")) {
        this.hideModal();
      }
    };
    document.addEventListener("keydown", this.escapeHandler);
  }

  disconnect() {
    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler);
    }
  }

  showModal(event) {
    if (event) event.preventDefault();
    this.modalTarget.classList.remove("tw-hidden");
    document.body.style.overflow = "hidden";
  }

  hideModal(event) {
    if (event) event.preventDefault();
    this.modalTarget.classList.add("tw-hidden");
    document.body.style.overflow = "";
  }

  loadFromUrl() {
    const params = new URLSearchParams(window.location.search);

    const intOrDefault = (key, fallback) => {
      const value = parseInt(params.get(key), 10);
      return Number.isNaN(value) ? fallback : value;
    };

    this.setValueForId(
      "setting-token-font-size",
      intOrDefault(
        "syntaxGraphTokenFontSize",
        this.defaults.syntaxGraphTokenFontSize
      )
    );
    this.setValueForId(
      "setting-tag-font-size",
      intOrDefault(
        "syntaxGraphTagFontSize",
        this.defaults.syntaxGraphTagFontSize
      )
    );
    this.setValueForId(
      "setting-header-font-size",
      intOrDefault(
        "syntaxGraphHeaderFontSize",
        this.defaults.syntaxGraphHeaderFontSize
      )
    );
    this.setValueForId(
      "setting-elided-font-size",
      intOrDefault(
        "syntaxGraphElidedWordFontSize",
        this.defaults.syntaxGraphElidedWordFontSize
      )
    );
    this.setValueForId(
      "setting-edge-label-font-size",
      intOrDefault(
        "syntaxGraphEdgeLabelFontSize",
        this.defaults.syntaxGraphEdgeLabelFontSize
      )
    );

    this.setValueForId(
      "setting-header-line-gap",
      intOrDefault(
        "syntaxGraphHeaderTextDeltaY",
        this.defaults.syntaxGraphHeaderTextDeltaY
      )
    );
    this.setValueForId(
      "setting-pos-tag-gap",
      intOrDefault("syntaxGraphPosTagGap", this.defaults.syntaxGraphPosTagGap)
    );
    this.setValueForId(
      "setting-bracket-delta-y",
      intOrDefault(
        "syntaxGraphBracketDeltaY",
        this.defaults.syntaxGraphBracketDeltaY
      )
    );

    this.setValueForId(
      "setting-word-gap",
      intOrDefault("syntaxGraphWordGap", this.defaults.syntaxGraphWordGap)
    );
    this.setValueForId(
      "setting-header-extra-gap",
      intOrDefault(
        "syntaxGraphHeaderExtraGap",
        this.defaults.syntaxGraphHeaderExtraGap
      )
    );
    this.setValueForId(
      "setting-pos-tag-y-offset",
      intOrDefault(
        "syntaxGraphPosTagYOffset",
        this.defaults.syntaxGraphPosTagYOffset
      )
    );

    this.setValueForId(
      "setting-default-font",
      params.get("defaultFont") || this.defaults.defaultFont
    );
    this.setValueForId(
      "setting-arabic-font",
      params.get("defaultArabicFont") || this.defaults.defaultArabicFont
    );
    this.setValueForId(
      "setting-elided-word-font",
      params.get("elidedWordFont") || this.defaults.elidedWordFont
    );
  }

  apply(event) {
    event.preventDefault();

    const theme = {
      fonts: {
        defaultFont: {
          family: this.valueForId("setting-default-font"),
        },
        defaultArabicFont: {
          family: this.valueForId("setting-arabic-font"),
        },
        elidedWordFont: {
          family: this.valueForId("setting-elided-word-font"),
        },
      },
      syntaxGraphTokenFontSize: this.intValueForId("setting-token-font-size"),
      syntaxGraphTagFontSize: this.intValueForId("setting-tag-font-size"),
      syntaxGraphHeaderFontSize: this.intValueForId("setting-header-font-size"),
      syntaxGraphElidedWordFontSize: this.intValueForId(
        "setting-elided-font-size"
      ),
      syntaxGraphEdgeLabelFontSize: this.intValueForId(
        "setting-edge-label-font-size"
      ),
      syntaxGraphHeaderTextDeltaY: this.intValueForId(
        "setting-header-line-gap"
      ),
      syntaxGraphPosTagGap: this.intValueForId("setting-pos-tag-gap"),
      syntaxGraphBracketDeltaY: this.intValueForId("setting-bracket-delta-y"),
      syntaxGraphWordGap: this.intValueForId("setting-word-gap"),
      syntaxGraphHeaderExtraGap: this.intValueForId("setting-header-extra-gap"),
      syntaxGraphPosTagYOffset: this.intValueForId("setting-pos-tag-y-offset"),
    };

    const url = new URL(window.location.href);
    const params = url.searchParams;

    params.set("syntaxGraphTokenFontSize", theme.syntaxGraphTokenFontSize);
    params.set("syntaxGraphTagFontSize", theme.syntaxGraphTagFontSize);
    params.set("syntaxGraphHeaderFontSize", theme.syntaxGraphHeaderFontSize);
    params.set(
      "syntaxGraphElidedWordFontSize",
      theme.syntaxGraphElidedWordFontSize
    );
    params.set(
      "syntaxGraphEdgeLabelFontSize",
      theme.syntaxGraphEdgeLabelFontSize
    );
    params.set(
      "syntaxGraphHeaderTextDeltaY",
      theme.syntaxGraphHeaderTextDeltaY
    );
    params.set("syntaxGraphPosTagGap", theme.syntaxGraphPosTagGap);
    params.set("syntaxGraphBracketDeltaY", theme.syntaxGraphBracketDeltaY);
    params.set("syntaxGraphWordGap", theme.syntaxGraphWordGap);
    params.set("syntaxGraphHeaderExtraGap", theme.syntaxGraphHeaderExtraGap);
    params.set("syntaxGraphPosTagYOffset", theme.syntaxGraphPosTagYOffset);
    params.set("defaultFont", theme.fonts.defaultFont.family);
    params.set("defaultArabicFont", theme.fonts.defaultArabicFont.family);
    params.set("elidedWordFont", theme.fonts.elidedWordFont.family);

    window.history.replaceState({}, "", url.toString());

    const graphElement = document.getElementById("main-syntax-graph");
    if (graphElement) {
      window.dispatchEvent(new CustomEvent("refresh-graph-preview"));
    }
  }

  reset(event) {
    event.preventDefault();

    this.setValueForId(
      "setting-token-font-size",
      this.defaults.syntaxGraphTokenFontSize
    );
    this.setValueForId(
      "setting-tag-font-size",
      this.defaults.syntaxGraphTagFontSize
    );
    this.setValueForId(
      "setting-header-font-size",
      this.defaults.syntaxGraphHeaderFontSize
    );
    this.setValueForId(
      "setting-elided-font-size",
      this.defaults.syntaxGraphElidedWordFontSize
    );
    this.setValueForId(
      "setting-edge-label-font-size",
      this.defaults.syntaxGraphEdgeLabelFontSize
    );
    this.setValueForId("setting-word-gap", this.defaults.syntaxGraphWordGap);
    this.setValueForId(
      "setting-header-extra-gap",
      this.defaults.syntaxGraphHeaderExtraGap
    );
    this.setValueForId(
      "setting-pos-tag-y-offset",
      this.defaults.syntaxGraphPosTagYOffset
    );
    this.setValueForId("setting-default-font", this.defaults.defaultFont);
    this.setValueForId("setting-arabic-font", this.defaults.defaultArabicFont);
    this.setValueForId(
      "setting-elided-word-font",
      this.defaults.elidedWordFont
    );

    const url = new URL(window.location.href);
    const params = url.searchParams;

    [
      "syntaxGraphTokenFontSize",
      "syntaxGraphTagFontSize",
      "syntaxGraphHeaderFontSize",
      "syntaxGraphElidedWordFontSize",
      "syntaxGraphEdgeLabelFontSize",
      "syntaxGraphHeaderTextDeltaY",
      "syntaxGraphPosTagGap",
      "syntaxGraphBracketDeltaY",
      "syntaxGraphWordGap",
      "syntaxGraphHeaderExtraGap",
      "syntaxGraphPosTagYOffset",
      "defaultFont",
      "defaultArabicFont",
      "elidedWordFont",
    ].forEach((key) => params.delete(key));

    window.history.replaceState({}, "", url.toString());

    const graphElement = document.getElementById("main-syntax-graph");
    if (graphElement) {
      window.dispatchEvent(new CustomEvent("refresh-graph-preview"));
    }
  }

  valueForId(id) {
    const el = this.element.querySelector(`#${id}`);
    return el ? el.value : "";
  }

  setValueForId(id, value) {
    const el = this.element.querySelector(`#${id}`);
    if (el) el.value = value;
  }

  intValueForId(id) {
    const value = parseInt(this.valueForId(id), 10);
    return Number.isNaN(value) ? null : value;
  }
}

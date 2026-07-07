import { Controller } from "@hotwired/stimulus";

export function collapseSentence(sentence, depth) {
  const phraseNodes = (sentence.phraseNodes || []).map(pn => Object.assign({}, pn, { span: [...pn.span] }));
  const originalTokens = (sentence.tokens || []).map(t => Object.assign({}, t));
  const originalEdges = (sentence.edges || []).map(e => Object.assign({}, e));

  const maxLevel = phraseNodes.length > 0 ? Math.max(...phraseNodes.map(pn => pn.level)) : 0;
  const collapseLevel = maxLevel - depth;

  if (collapseLevel <= 0) {
    return Object.assign({}, sentence, {
      tokens: originalTokens,
      edges: originalEdges,
      phraseNodes: phraseNodes,
    });
  }

  const isSpanContainedIn = (inner, outer) =>
    outer.span[0] <= inner.span[0] && outer.span[1] >= inner.span[1];

  const collapsibleNodes = phraseNodes.filter(pn => pn.level <= collapseLevel);
  const openedNodes = phraseNodes.filter(pn => pn.level > collapseLevel);

  const topCollapsedUnits = collapsibleNodes.filter(pn =>
    !collapsibleNodes.some(other => other !== pn && isSpanContainedIn(pn, other))
  );

  const visibleOpenedNodes = openedNodes.filter(o =>
    !topCollapsedUnits.some(u => isSpanContainedIn(o, u))
  );

  const coveredByUnit = (position) => {
    let owner = null;
    for (const u of topCollapsedUnits) {
      if (u.span[0] <= position && u.span[1] >= position) {
        if (!owner || (u.span[1] - u.span[0]) < (owner.span[1] - owner.span[0])) owner = u;
      }
    }
    return owner;
  };

  const newTokens = [];
  const unitSyntheticIndex = new Map();
  const usedUnits = new Set();
  let pos = 0;

  for (const tok of originalTokens) {
    const unit = coveredByUnit(tok.position);
    if (unit) {
      if (!usedUnits.has(unit)) {
        usedUnits.add(unit);
        unitSyntheticIndex.set(unit, pos);
        newTokens.push({
          position: pos,
          location: null,
          arabic: unit.text,
          posKey: unit.labelKey,
          posLabel: unit.label,
          colorClass: "green",
          tokenType: "phrase_unit",
          wordUrl: null,
        });
        pos++;
      }
    } else {
      newTokens.push(Object.assign({}, tok, { position: pos }));
      pos++;
    }
  }

  const origPosToNewPos = {};
  const origNonUnitTokens = originalTokens.filter(t => !coveredByUnit(t.position));
  const nonUnitNewTokens = newTokens.filter(t => t.tokenType !== "phrase_unit");
  for (let i = 0; i < origNonUnitTokens.length; i++) {
    origPosToNewPos[origNonUnitTokens[i].position] = nonUnitNewTokens[i].position;
  }
  for (const orig of originalTokens) {
    const unit = coveredByUnit(orig.position);
    if (unit) origPosToNewPos[orig.position] = unitSyntheticIndex.get(unit);
  }

  const remapPosition = (value) => {
    const mapped = origPosToNewPos[value];
    return mapped !== undefined ? mapped : value;
  };

  const remapCentroid = (value) => {
    const floor = Math.floor(value);
    const ceil = Math.ceil(value);
    const lo = origPosToNewPos[floor];
    const hi = origPosToNewPos[ceil];
    if (lo === undefined && hi === undefined) return value;
    if (lo === undefined) return hi;
    if (hi === undefined) return lo;
    if (floor === ceil) return lo;
    return lo + (hi - lo) * (value - floor);
  };

  const remappedPhraseNodes = visibleOpenedNodes.map(pn => Object.assign({}, pn, {
    span: [remapPosition(pn.span[0]), remapPosition(pn.span[1])],
    centroid: remapCentroid(pn.centroid),
    headPosition: remapPosition(pn.headPosition),
  }));

  const resolveEndpoint = (edgePos, isPhrase) => {
    if (isPhrase) {
      const pn = phraseNodes.find(p => p.headPosition === edgePos)
        || phraseNodes
          .filter(p => p.span[0] <= edgePos && p.span[1] >= edgePos)
          .sort((a, b) => (a.span[1] - a.span[0]) - (b.span[1] - b.span[0]))[0];
      if (pn) {
        const unit = topCollapsedUnits.find(u => isSpanContainedIn(pn, u));
        if (unit) return { pos: unitSyntheticIndex.get(unit), isPhrase: false };
        if (visibleOpenedNodes.includes(pn)) {
          return { pos: remapPosition(edgePos), isPhrase: true };
        }
      }
      const coveringUnit = coveredByUnit(edgePos);
      if (coveringUnit) return { pos: unitSyntheticIndex.get(coveringUnit), isPhrase: false };
      return { pos: remapPosition(edgePos), isPhrase: false };
    }
    const unit = coveredByUnit(edgePos);
    if (unit) return { pos: unitSyntheticIndex.get(unit), isPhrase: false };
    return { pos: remapPosition(edgePos), isPhrase: false };
  };

  const newEdges = [];
  const seen = new Set();
  for (const edge of originalEdges) {
    const fromResolved = resolveEndpoint(edge.from, edge.fromIsPhrase);
    const toResolved = resolveEndpoint(edge.to, edge.toIsPhrase);
    if (fromResolved.pos === toResolved.pos && !fromResolved.isPhrase && !toResolved.isPhrase) continue;
    const edgeKey = `${fromResolved.pos}:${fromResolved.isPhrase}:${toResolved.pos}:${toResolved.isPhrase}:${edge.relation}`;
    if (seen.has(edgeKey)) continue;
    seen.add(edgeKey);
    newEdges.push(Object.assign({}, edge, {
      from: fromResolved.pos,
      to: toResolved.pos,
      fromIsPhrase: fromResolved.isPhrase,
      toIsPhrase: toResolved.isPhrase,
    }));
  }

  return Object.assign({}, sentence, {
    tokens: newTokens,
    edges: newEdges,
    phraseNodes: remappedPhraseNodes,
  });
}

export default class extends Controller {
  static targets = ["container", "canvas", "zoomIn", "zoomOut", "zoomReset", "download", "accordionList"];
  static values = {
    url: String,
    expandable: Boolean,
  };

  connect() {
    this.zoomLevel = 1.0;
    this.sentenceStates = [];
    this.payload = null;
    if (this.hasUrlValue) {
      this.loadData();
    }
  }

  zoomIn() {
    this.zoomLevel = Math.min(2.0, parseFloat((this.zoomLevel + 0.1).toFixed(1)));
    this.applyZoom();
  }

  zoomOut() {
    this.zoomLevel = Math.max(0.5, parseFloat((this.zoomLevel - 0.1).toFixed(1)));
    this.applyZoom();
  }

  zoomReset() {
    this.zoomLevel = 1.0;
    this.applyZoom();
  }

  applyZoom() {
    let scope;
    if (this.expandableValue && this.hasAccordionListTarget) {
      scope = this.accordionListTarget;
    } else {
      scope = this.containerTarget.querySelector(".treebank-zoom-wrapper");
    }
    if (!scope) return;
    scope.querySelectorAll("svg[data-base-width]").forEach(svg => {
      const bw = parseFloat(svg.getAttribute("data-base-width"));
      const bh = parseFloat(svg.getAttribute("data-base-height"));
      svg.setAttribute("width", bw * this.zoomLevel);
      svg.setAttribute("height", bh * this.zoomLevel);
    });
  }

  async loadData() {
    try {
      if (!this.expandableValue) {
        this.containerTarget.textContent = "Loading treebank...";
      }
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      this.payload = data;
      if (this.expandableValue) {
        await this.renderAccordion(data);
      } else {
        await this.renderAll(data);
      }
    } catch (err) {
      console.error("Treebank load failed:", err);
      const errorEl = document.createElement("div");
      errorEl.className = "text-red-500 p-4";
      errorEl.textContent = "Failed to load treebank data.";
      const host = this.expandableValue && this.hasAccordionListTarget ? this.accordionListTarget : this.containerTarget;
      host.innerHTML = "";
      host.appendChild(errorEl);
    }
  }

  async renderAll(payload) {
    const sentences = payload.sentences || [];
    this.containerTarget.innerHTML = "";

    await document.fonts.load("1em qpc-hafs");

    const zoomWrapper = document.createElement("div");
    zoomWrapper.className = "treebank-zoom-wrapper";
    this.containerTarget.appendChild(zoomWrapper);

    for (let i = 0; i < sentences.length; i++) {
      const sentence = sentences[i];
      const renderer = new TreebankRenderer(sentence);
      const svg = await renderer.render();
      const wrapper = document.createElement("div");
      wrapper.className = "treebank-sentence-wrap";
      if (i === 0) {
        wrapper.setAttribute("data-syntax-graph-download-target", "graphContainer");
      }
      wrapper.appendChild(svg);
      zoomWrapper.appendChild(wrapper);
    }

    this.applyZoom();
  }

  sentenceMaxLevel(sentence) {
    const phraseNodes = sentence.phraseNodes || [];
    return phraseNodes.length > 0 ? Math.max(...phraseNodes.map(pn => pn.level)) : 0;
  }

  async renderAccordion(payload) {
    const sentences = payload.sentences || [];
    await document.fonts.load("1em qpc-hafs");

    this.sentenceStates = sentences.map((_, i) => ({ expanded: i === 0, depth: 0 }));

    this.accordionListTarget.innerHTML = "";

    for (let i = 0; i < sentences.length; i++) {
      const card = this.buildCard(sentences[i], i);
      this.accordionListTarget.appendChild(card);
      if (this.sentenceStates[i].expanded) {
        await this.renderCardSvg(i);
      }
    }

    this.updateDownloadTarget();
  }

  buildCard(sentence, idx) {
    const maxLevel = this.sentenceMaxLevel(sentence);
    const state = this.sentenceStates[idx];

    const card = document.createElement("div");
    card.className = "tb-card";
    card.setAttribute("data-sentence-idx", idx);

    const header = document.createElement("div");
    header.className = "tb-card-header";

    const titleArea = document.createElement("div");
    titleArea.className = "tb-card-title";

    const titleText = document.createElement("span");
    titleText.className = "tb-card-title-text";
    titleText.textContent = `Sentence ${idx + 1}`;

    const rangeSpan = document.createElement("span");
    rangeSpan.className = "tb-card-range";
    rangeSpan.textContent = sentence.verseRange || "";

    const countSpan = document.createElement("span");
    countSpan.className = "tb-card-count";
    countSpan.textContent = `${(sentence.tokens || []).length} tokens`;

    const snippetSpan = document.createElement("span");
    snippetSpan.className = "tb-card-snippet";
    const bannerText = (sentence.banner && sentence.banner.text) || "";
    snippetSpan.textContent = bannerText.length > 80 ? `${bannerText.slice(0, 80)}…` : bannerText;

    titleArea.appendChild(titleText);
    titleArea.appendChild(rangeSpan);
    titleArea.appendChild(countSpan);
    titleArea.appendChild(snippetSpan);

    const chevron = document.createElement("button");
    chevron.type = "button";
    chevron.className = "tb-card-chevron";
    chevron.setAttribute("data-action", "click->treebank#toggleCard");
    chevron.setAttribute("data-idx", idx);
    chevron.setAttribute("title", "Expand or collapse");
    const chevronIcon = document.createElement("i");
    chevronIcon.className = state.expanded ? "fa fa-chevron-up" : "fa fa-chevron-down";
    chevron.appendChild(chevronIcon);

    header.appendChild(titleArea);
    header.appendChild(chevron);
    card.appendChild(header);

    const body = document.createElement("div");
    body.className = state.expanded ? "tb-card-body" : "tb-card-body hidden";

    if (maxLevel > 0) {
      const controls = document.createElement("div");
      controls.className = "tb-card-controls";

      const mkBtn = (action, label) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "tb-btn-level";
        btn.setAttribute("data-action", `click->treebank#${action}`);
        btn.setAttribute("data-idx", idx);
        btn.textContent = label;
        return btn;
      };

      const depthDisplay = document.createElement("span");
      depthDisplay.className = "tb-depth-display";
      depthDisplay.setAttribute("data-depth-display", idx);
      depthDisplay.textContent = `${state.depth} / ${maxLevel}`;

      controls.appendChild(mkBtn("levelDown", "− level"));
      controls.appendChild(depthDisplay);
      controls.appendChild(mkBtn("levelUp", "+ level"));
      controls.appendChild(mkBtn("expandAllLevels", "expand all"));
      controls.appendChild(mkBtn("collapseAllLevels", "collapse all"));
      body.appendChild(controls);
    }

    const svgContainer = document.createElement("div");
    svgContainer.className = "tb-card-svg-container";
    body.appendChild(svgContainer);
    card.appendChild(body);

    return card;
  }

  cardFor(idx) {
    return this.accordionListTarget.querySelector(`[data-sentence-idx="${idx}"]`);
  }

  fixSyntheticLabelLinks(svg, transformed) {
    const syntheticKeys = new Set(
      (transformed.tokens || [])
        .filter(t => t.tokenType === "phrase_unit" && t.posKey)
        .map(t => encodeURIComponent(t.posKey))
    );
    if (syntheticKeys.size === 0) return;
    svg.querySelectorAll("a[data-url]").forEach(link => {
      const url = link.getAttribute("data-url") || "";
      const match = url.match(/\/morphology\/grammar\/pos_tags\/([^?]+)/);
      if (!match || !syntheticKeys.has(match[1])) return;
      const fixed = url.replace("/morphology/grammar/pos_tags/", "/morphology/grammar/edge_relations/");
      link.setAttribute("data-url", fixed);
      link.setAttribute("href", fixed);
      link.setAttributeNS("http://www.w3.org/1999/xlink", "xlink:href", fixed);
    });
  }

  async renderCardSvg(idx) {
    const sentences = (this.payload && this.payload.sentences) || [];
    const sentence = sentences[idx];
    const card = this.cardFor(idx);
    if (!sentence || !card) return;

    const svgContainer = card.querySelector(".tb-card-svg-container");
    if (!svgContainer) return;

    const transformed = collapseSentence(sentence, this.sentenceStates[idx].depth);
    const renderer = new TreebankRenderer(transformed);
    const svg = await renderer.render();
    this.fixSyntheticLabelLinks(svg, transformed);
    svgContainer.innerHTML = "";
    svgContainer.appendChild(svg);
    this.applyZoom();
  }

  async toggleCard(event) {
    const idx = parseInt(event.currentTarget.getAttribute("data-idx"), 10);
    if (isNaN(idx) || !this.sentenceStates[idx]) return;

    const state = this.sentenceStates[idx];
    state.expanded = !state.expanded;

    const card = this.cardFor(idx);
    if (!card) return;

    const body = card.querySelector(".tb-card-body");
    const chevronIcon = card.querySelector(".tb-card-chevron i");

    if (state.expanded) {
      body.classList.remove("hidden");
      if (chevronIcon) chevronIcon.className = "fa fa-chevron-up";
      const svgContainer = card.querySelector(".tb-card-svg-container");
      if (svgContainer && !svgContainer.querySelector("svg")) {
        await this.renderCardSvg(idx);
      }
    } else {
      body.classList.add("hidden");
      if (chevronIcon) chevronIcon.className = "fa fa-chevron-down";
    }

    this.updateDownloadTarget();
  }

  async changeDepth(idx, newDepth) {
    const sentences = (this.payload && this.payload.sentences) || [];
    const sentence = sentences[idx];
    if (!sentence) return;

    const maxLevel = this.sentenceMaxLevel(sentence);
    const clamped = Math.max(0, Math.min(maxLevel, newDepth));
    if (clamped === this.sentenceStates[idx].depth) return;
    this.sentenceStates[idx].depth = clamped;

    const card = this.cardFor(idx);
    if (card) {
      const depthDisplay = card.querySelector(`[data-depth-display="${idx}"]`);
      if (depthDisplay) depthDisplay.textContent = `${clamped} / ${maxLevel}`;
    }

    await this.renderCardSvg(idx);
  }

  async levelDown(event) {
    const idx = parseInt(event.currentTarget.getAttribute("data-idx"), 10);
    if (isNaN(idx) || !this.sentenceStates[idx]) return;
    await this.changeDepth(idx, this.sentenceStates[idx].depth - 1);
  }

  async levelUp(event) {
    const idx = parseInt(event.currentTarget.getAttribute("data-idx"), 10);
    if (isNaN(idx) || !this.sentenceStates[idx]) return;
    await this.changeDepth(idx, this.sentenceStates[idx].depth + 1);
  }

  async expandAllLevels(event) {
    const idx = parseInt(event.currentTarget.getAttribute("data-idx"), 10);
    if (isNaN(idx) || !this.sentenceStates[idx]) return;
    const sentences = (this.payload && this.payload.sentences) || [];
    const sentence = sentences[idx];
    if (!sentence) return;
    await this.changeDepth(idx, this.sentenceMaxLevel(sentence));
  }

  async collapseAllLevels(event) {
    const idx = parseInt(event.currentTarget.getAttribute("data-idx"), 10);
    if (isNaN(idx) || !this.sentenceStates[idx]) return;
    await this.changeDepth(idx, 0);
  }

  updateDownloadTarget() {
    if (!this.hasAccordionListTarget) return;
    this.accordionListTarget.querySelectorAll(".tb-card-svg-container").forEach(el => {
      el.removeAttribute("data-syntax-graph-download-target");
    });
    const firstExpanded = this.sentenceStates.findIndex(s => s.expanded);
    if (firstExpanded === -1) return;
    const card = this.cardFor(firstExpanded);
    if (!card) return;
    const svgContainer = card.querySelector(".tb-card-svg-container");
    if (svgContainer) svgContainer.setAttribute("data-syntax-graph-download-target", "graphContainer");
  }
}

class TreebankRenderer {
  constructor(sentence) {
    this.sentence = sentence;
    this.locale = sentence.locale || "ar";

    this.arabicFont = "qpc-hafs";
    this.labelFont = "Arial, sans-serif";
    this.tokenFontSize = 32;
    this.posLabelFontSize = 14;
    this.locationFontSize = 11;
    this.bannerFontSize = 22;
    this.bannerRefFontSize = 14;
    this.edgeLabelFontSize = 13;

    this.slotWidth = 90;
    this.slotGap = 20;
    this.bannerHeight = 70;
    this.phraseLevelHeight = 0;
    this.PHRASE_LEVEL_STEP = 70;
    this.tokenRowHeight = 90;
    this.arcBandHeight = 0;
    this.padding = 20;
    this.SVG_NS = "http://www.w3.org/2000/svg";
    this.XLINK_NS = "http://www.w3.org/1999/xlink";
  }

  grammarUrl(category, term) {
    return `/morphology/grammar/${encodeURIComponent(category)}/${encodeURIComponent(term)}?locale=${encodeURIComponent(this.locale)}`;
  }

  async render() {
    const tokens = this.sentence.tokens || [];
    const allEdges = this.sentence.edges || [];
    const edges = allEdges.filter(e => !e.fromIsPhrase && !e.toIsPhrase);
    const phraseEdges = allEdges.filter(e => e.fromIsPhrase || e.toIsPhrase);
    const phraseNodes = this.sentence.phraseNodes || [];
    const maxLevel = phraseNodes.length > 0 ? Math.max(...phraseNodes.map(pn => pn.level)) : 0;
    this.phraseLevelHeight = maxLevel * this.PHRASE_LEVEL_STEP;

    const tempSvg = document.createElementNS(this.SVG_NS, "svg");
    tempSvg.style.position = "absolute";
    tempSvg.style.visibility = "hidden";
    tempSvg.style.top = "-9999px";
    document.body.appendChild(tempSvg);

    const slotWidths = tokens.map(tok => {
      const arabicW = this.measureText(tempSvg, tok.arabic || "", this.arabicFont, this.tokenFontSize);
      const posW = this.measureText(tempSvg, tok.posLabel || "", this.arabicFont, this.posLabelFontSize);
      const locW = this.measureText(tempSvg, tok.location || "", this.labelFont, this.locationFontSize);
      return Math.max(arabicW + 24, posW + 16, locW + 16, this.slotWidth);
    });

    const totalTokenWidth = slotWidths.reduce((s, w) => s + w, 0) + this.slotGap * Math.max(0, tokens.length - 1);
    const svgW = totalTokenWidth + this.padding * 2;

    const positionToCenter = this.buildPositionToCenter(tokens, slotWidths, svgW);
    const tokenCenters = tokens.map(tok => positionToCenter[tok.position] ?? 0);
    const arcData = this.computeArcsFromMap(tokens, edges, positionToCenter);
    const arcBandHeight = arcData.length > 0 ? (arcData.reduce((m, a) => Math.max(m, a.apexY), 0) + 40) : 0;

    const svgH = this.bannerHeight + this.phraseLevelHeight + arcBandHeight + this.tokenRowHeight + this.padding;

    const bannerText = (this.sentence.banner && this.sentence.banner.text) || "";
    const bannerTextW = this.measureText(tempSvg, bannerText, this.arabicFont, this.bannerFontSize);

    document.body.removeChild(tempSvg);

    const svg = document.createElementNS(this.SVG_NS, "svg");
    svg.setAttribute("width", svgW);
    svg.setAttribute("height", svgH);
    svg.setAttribute("viewBox", `0 0 ${svgW} ${svgH}`);
    svg.setAttribute("xmlns", this.SVG_NS);
    svg.setAttribute("data-base-width", svgW);
    svg.setAttribute("data-base-height", svgH);
    svg.style.maxWidth = "100%";
    svg.style.display = "block";

    this.drawBanner(svg, svgW, bannerTextW);

    const tokenRowY = this.bannerHeight + this.phraseLevelHeight + arcBandHeight;

    let phraseDotPositions = new Map();
    if (phraseNodes.length > 0) {
      phraseDotPositions = this.drawPhraseLevel(svg, phraseNodes, positionToCenter, tokenRowY, maxLevel);
    }

    this.drawBannerConnectors(svg, phraseNodes, phraseDotPositions, tokens, positionToCenter, svgW, tokenRowY);

    if (arcData.length > 0) {
      this.drawArcs(svg, arcData, tokenRowY);
    }

    if (phraseEdges.length > 0) {
      this.drawPhraseEdges(svg, phraseEdges, phraseNodes, phraseDotPositions, positionToCenter, tokenRowY, tokens);
    }

    this.drawTokens(svg, tokens, tokenCenters, tokenRowY);

    return svg;
  }

  measureText(svg, text, fontFamily, fontSize) {
    if (!text) return 0;
    const t = document.createElementNS(this.SVG_NS, "text");
    t.textContent = text;
    t.setAttribute("font-family", fontFamily);
    t.setAttribute("font-size", fontSize);
    svg.appendChild(t);
    try {
      const bb = t.getBBox();
      svg.removeChild(t);
      return bb.width || text.length * fontSize * 0.6;
    } catch (_) {
      svg.removeChild(t);
      return text.length * fontSize * 0.6;
    }
  }

  buildPositionToCenter(tokens, slotWidths, svgW) {
    const map = {};
    let x = svgW - this.padding;
    for (let i = 0; i < tokens.length; i++) {
      const tok = tokens[i];
      x -= slotWidths[i];
      map[tok.position] = x + slotWidths[i] / 2;
      if (i < tokens.length - 1) x -= this.slotGap;
    }
    return map;
  }

  centroidToX(centroid, positionToCenter) {
    const floor = Math.floor(centroid);
    const ceil = Math.ceil(centroid);
    if (floor === ceil) return positionToCenter[floor] ?? 0;
    const xFloor = positionToCenter[floor];
    const xCeil = positionToCenter[ceil];
    if (xFloor === undefined && xCeil === undefined) return 0;
    if (xFloor === undefined) return xCeil;
    if (xCeil === undefined) return xFloor;
    const frac = centroid - floor;
    return xFloor + (xCeil - xFloor) * frac;
  }

  phraseDotY(level, maxLevel) {
    return this.bannerHeight + (maxLevel - level) * this.PHRASE_LEVEL_STEP + this.PHRASE_LEVEL_STEP / 2;
  }

  computeArcsFromMap(tokens, edges, positionToCenter) {
    const arcList = edges.map(edge => {
      const fromX = positionToCenter[edge.from];
      const toX = positionToCenter[edge.to];
      if (fromX === undefined || toX === undefined) return null;
      const span = Math.abs(edge.from - edge.to);
      return { edge, fromX, toX, span, apexY: 0 };
    }).filter(Boolean);

    arcList.sort((a, b) => a.span - b.span);

    const RANK_STEP = 50;
    const ARC_STEP = 25;

    const distinctSpans = [...new Set(arcList.map(a => a.span))].sort((a, b) => a - b);
    const spanRank = {};
    distinctSpans.forEach((span, idx) => { spanRank[span] = idx; });

    const occupiedBands = [];

    for (const arc of arcList) {
      const x1 = Math.min(arc.fromX, arc.toX);
      const x2 = Math.max(arc.fromX, arc.toX);
      let apexY = (spanRank[arc.span] + 1) * RANK_STEP;

      let collision = true;
      while (collision) {
        collision = false;
        for (const band of occupiedBands) {
          if (!(x2 < band.x1 || x1 > band.x2) && Math.abs(apexY - band.apexY) < ARC_STEP) {
            apexY = band.apexY + ARC_STEP;
            collision = true;
            break;
          }
        }
      }

      arc.apexY = apexY;
      occupiedBands.push({ x1, x2, apexY });
    }

    return arcList;
  }

  drawBanner(svg, svgW, bannerTextW) {
    const bannerText = (this.sentence.banner && this.sentence.banner.text) || "";
    const refText = (this.sentence.banner && this.sentence.banner.reference) || "";
    const cx = svgW / 2;

    const bannerTextEl = document.createElementNS(this.SVG_NS, "text");
    bannerTextEl.textContent = bannerText;
    bannerTextEl.setAttribute("x", cx);
    bannerTextEl.setAttribute("y", 32);
    bannerTextEl.setAttribute("font-family", this.arabicFont);
    bannerTextEl.setAttribute("font-size", this.bannerFontSize);
    bannerTextEl.setAttribute("text-anchor", "middle");
    bannerTextEl.setAttribute("dominant-baseline", "middle");
    bannerTextEl.classList.add("treebank-banner-text");
    svg.appendChild(bannerTextEl);

    const refEl = document.createElementNS(this.SVG_NS, "text");
    refEl.textContent = refText;
    refEl.setAttribute("x", cx);
    refEl.setAttribute("y", 56);
    refEl.setAttribute("font-family", this.arabicFont);
    refEl.setAttribute("font-size", this.bannerRefFontSize);
    refEl.setAttribute("text-anchor", "middle");
    refEl.setAttribute("dominant-baseline", "middle");
    refEl.classList.add("treebank-banner-ref");
    svg.appendChild(refEl);

    const textW = (bannerTextW && bannerTextW > 0) ? bannerTextW : Math.min(svgW - this.padding * 2, bannerText.length * this.bannerFontSize * 0.6);
    const ulX1 = cx - textW / 2;
    const ulX2 = cx + textW / 2;
    const underline = document.createElementNS(this.SVG_NS, "line");
    underline.setAttribute("x1", ulX1);
    underline.setAttribute("y1", this.bannerHeight - 4);
    underline.setAttribute("x2", ulX2);
    underline.setAttribute("y2", this.bannerHeight - 4);
    underline.classList.add("treebank-banner-underline");
    svg.appendChild(underline);
  }

  phraseConnectorPath(svg, x1, y1, x2, y2) {
    const path = document.createElementNS(this.SVG_NS, "path");
    path.setAttribute("d", `M ${x1},${y1} L ${x2},${y2}`);
    path.setAttribute("fill", "none");
    path.setAttribute("stroke", "#4472C4");
    path.setAttribute("stroke-width", "0.6");
    path.setAttribute("stroke-dasharray", "2.6 2");
    path.classList.add("treebank-phrase-link");
    svg.appendChild(path);
  }

  drawPhraseLevel(svg, phraseNodes, positionToCenter, tokenRowY, maxLevel) {
    const phraseDotPositions = new Map();
    const DOT_R = 5;
    const TOKEN_TOP_Y_OFFSET = 6;

    for (const pn of phraseNodes) {
      const x = this.centroidToX(pn.centroid, positionToCenter);
      const y = this.phraseDotY(pn.level, maxLevel);
      phraseDotPositions.set(pn, { x, y });
    }

    for (const pn of phraseNodes) {
      const parent = this.findParentPhrase(pn, phraseNodes);
      if (!parent) continue;
      const { x: dotX, y: dotY } = phraseDotPositions.get(pn);
      const { x: parentX, y: parentY } = phraseDotPositions.get(parent);
      this.phraseConnectorPath(svg, dotX, dotY, parentX, parentY);
    }

    const allPositions = new Set();
    for (const pn of phraseNodes) {
      for (let pos = pn.span[0]; pos <= pn.span[1]; pos++) {
        allPositions.add(pos);
      }
    }

    for (const pos of allPositions) {
      const tokX = positionToCenter[pos];
      if (tokX === undefined) continue;
      const owner = this.findSmallestCoveringPhrase(pos, phraseNodes);
      if (!owner) continue;
      const { x: dotX, y: dotY } = phraseDotPositions.get(owner);
      this.phraseConnectorPath(svg, tokX, tokenRowY - TOKEN_TOP_Y_OFFSET, dotX, dotY);
    }

    for (const pn of phraseNodes) {
      const { x: dotX, y: dotY } = phraseDotPositions.get(pn);

      const circle = document.createElementNS(this.SVG_NS, "circle");
      circle.setAttribute("cx", dotX);
      circle.setAttribute("cy", dotY);
      circle.setAttribute("r", DOT_R);
      circle.classList.add("treebank-phrase-dot");
      svg.appendChild(circle);

      const textEl = document.createElementNS(this.SVG_NS, "text");
      textEl.textContent = pn.text || "";
      textEl.setAttribute("x", dotX);
      textEl.setAttribute("y", dotY - DOT_R - 4);
      textEl.setAttribute("font-family", this.arabicFont);
      textEl.setAttribute("font-size", "13");
      textEl.setAttribute("text-anchor", "middle");
      textEl.setAttribute("dominant-baseline", "auto");
      textEl.classList.add("treebank-phrase-text");
      svg.appendChild(textEl);

      if (pn.label && pn.labelKey) {
        const labelUrl = this.grammarUrl("edge_relations", pn.labelKey);
        const linkEl = document.createElementNS(this.SVG_NS, "a");
        linkEl.setAttribute("href", labelUrl);
        linkEl.setAttributeNS(this.XLINK_NS, "xlink:href", labelUrl);
        linkEl.setAttribute("data-controller", "ajax-modal");
        linkEl.setAttribute("data-url", labelUrl);

        const labelEl = document.createElementNS(this.SVG_NS, "text");
        labelEl.textContent = pn.label;
        labelEl.setAttribute("x", dotX);
        labelEl.setAttribute("y", dotY + DOT_R + 14);
        labelEl.setAttribute("font-family", this.arabicFont);
        labelEl.setAttribute("font-size", "12");
        labelEl.setAttribute("text-anchor", "middle");
        labelEl.setAttribute("dominant-baseline", "hanging");
        labelEl.classList.add("treebank-phrase-label", "term-link");
        linkEl.appendChild(labelEl);
        svg.appendChild(linkEl);
      }
    }

    return phraseDotPositions;
  }

  drawBannerConnectors(svg, phraseNodes, phraseDotPositions, tokens, positionToCenter, svgW, tokenRowY) {
    const bannerAnchorX = svgW / 2;
    const bannerAnchorY = this.bannerHeight - 4;

    const bannerDot = document.createElementNS(this.SVG_NS, "circle");
    bannerDot.setAttribute("cx", bannerAnchorX);
    bannerDot.setAttribute("cy", bannerAnchorY);
    bannerDot.setAttribute("r", 4);
    bannerDot.classList.add("treebank-phrase-dot");
    svg.appendChild(bannerDot);

    const topPhraseNodes = phraseNodes.filter(pn => {
      return !phraseNodes.some(other =>
        other !== pn &&
        other.level > pn.level &&
        other.span[0] <= pn.span[0] &&
        other.span[1] >= pn.span[1]
      );
    });

    const coveredPositions = new Set();
    for (const pn of phraseNodes) {
      for (let p = pn.span[0]; p <= pn.span[1]; p++) {
        coveredPositions.add(p);
      }
    }

    for (const pn of topPhraseNodes) {
      const pos = phraseDotPositions.get(pn);
      if (pos) this.phraseConnectorPath(svg, pos.x, pos.y, bannerAnchorX, bannerAnchorY);
    }

    const topTokenY = tokenRowY - 6;
    const bandAnchorY = this.bannerHeight + this.phraseLevelHeight;
    for (const tok of tokens) {
      if (coveredPositions.has(tok.position)) continue;
      const tokX = positionToCenter[tok.position];
      if (tokX === undefined) continue;
      if (this.phraseLevelHeight > 0) {
        this.phraseConnectorPath(svg, bannerAnchorX, bannerAnchorY, tokX, bandAnchorY);
        this.phraseConnectorPath(svg, tokX, bandAnchorY, tokX, topTokenY);
      } else {
        this.phraseConnectorPath(svg, bannerAnchorX, bannerAnchorY, tokX, topTokenY);
      }
    }
  }

  findParentPhrase(pn, phraseNodes) {
    const containing = phraseNodes.filter(other =>
      other !== pn &&
      other.level > pn.level &&
      other.span[0] <= pn.span[0] &&
      other.span[1] >= pn.span[1]
    );
    if (containing.length === 0) return null;
    containing.sort((a, b) => {
      const sizeDiff = (a.span[1] - a.span[0]) - (b.span[1] - b.span[0]);
      if (sizeDiff !== 0) return sizeDiff;
      return a.level - b.level;
    });
    return containing[0];
  }

  findSmallestCoveringPhrase(position, phraseNodes) {
    const covering = phraseNodes.filter(pn =>
      pn.span[0] <= position && pn.span[1] >= position
    );
    if (covering.length === 0) return null;
    covering.sort((a, b) => (a.span[1] - a.span[0]) - (b.span[1] - b.span[0]));
    return covering[0];
  }

  drawDuplicateTokenBlock(svg, tok, x, y, colorClass) {
    const DOT_R = 5;
    const UNDERLINE_W = 28;
    const LABEL_OFFSET = 14;

    const circle = document.createElementNS(this.SVG_NS, "circle");
    circle.setAttribute("cx", x);
    circle.setAttribute("cy", y);
    circle.setAttribute("r", DOT_R);
    circle.classList.add("treebank-phrase-dot");
    svg.appendChild(circle);

    const textEl = document.createElementNS(this.SVG_NS, "text");
    textEl.textContent = tok.arabic || "";
    textEl.setAttribute("x", x);
    textEl.setAttribute("y", y - DOT_R - 4);
    textEl.setAttribute("font-family", this.arabicFont);
    textEl.setAttribute("font-size", "13");
    textEl.setAttribute("text-anchor", "middle");
    textEl.setAttribute("dominant-baseline", "auto");
    if (colorClass) textEl.classList.add(colorClass);
    svg.appendChild(textEl);

    const ul = document.createElementNS(this.SVG_NS, "line");
    ul.setAttribute("x1", x - UNDERLINE_W / 2);
    ul.setAttribute("y1", y - DOT_R - 5);
    ul.setAttribute("x2", x + UNDERLINE_W / 2);
    ul.setAttribute("y2", y - DOT_R - 5);
    ul.setAttribute("stroke", colorClass ? null : "#333");
    ul.setAttribute("stroke-width", "0.8");
    if (colorClass) ul.classList.add(colorClass);
    svg.appendChild(ul);

    if (tok.posLabel) {
      const posEl = document.createElementNS(this.SVG_NS, "text");
      posEl.textContent = tok.posLabel;
      posEl.setAttribute("x", x);
      posEl.setAttribute("y", y + DOT_R + LABEL_OFFSET);
      posEl.setAttribute("font-family", this.arabicFont);
      posEl.setAttribute("font-size", "12");
      posEl.setAttribute("text-anchor", "middle");
      posEl.setAttribute("dominant-baseline", "hanging");
      if (colorClass) posEl.classList.add(colorClass);
      posEl.classList.add("treebank-phrase-label");
      svg.appendChild(posEl);
    }
  }

  drawPhraseEdges(svg, phraseEdges, phraseNodes, phraseDotPositions, positionToCenter, tokenRowY, tokens) {
    const ARC_HEIGHT = 50;
    const DOT_R = 5;

    const allBandY = [...phraseDotPositions.values()].map(p => p.y);
    const defaultBandY = allBandY.length > 0 ? Math.min(...allBandY) : tokenRowY - ARC_HEIGHT * 2;

    const tokensByPos = {};
    if (tokens) tokens.forEach(t => { tokensByPos[t.position] = t; });

    for (const edge of phraseEdges) {
      let fromX = null;
      let fromY = null;
      let toX = null;
      let toY = null;

      if (edge.fromIsPhrase) {
        const pn = phraseNodes.find(pn => pn.headPosition === edge.from)
               || this.findSmallestCoveringPhrase(edge.from, phraseNodes);
        const pos = pn ? phraseDotPositions.get(pn) : null;
        if (!pos) continue;
        fromX = pos.x;
        fromY = pos.y;
      } else {
        const baseX = positionToCenter[edge.from] ?? null;
        if (baseX === null) continue;
        const bandY = defaultBandY;
        const tok = tokensByPos[edge.from];
        if (tok) {
          this.drawDuplicateTokenBlock(svg, tok, baseX, bandY, tok.colorClass);
          const dotLine = document.createElementNS(this.SVG_NS, "path");
          dotLine.setAttribute("d", `M ${baseX},${tokenRowY - 6} L ${baseX},${bandY + DOT_R}`);
          dotLine.setAttribute("fill", "none");
          dotLine.setAttribute("stroke", "#4472C4");
          dotLine.setAttribute("stroke-width", "0.8");
          dotLine.setAttribute("stroke-dasharray", "3 2");
          svg.appendChild(dotLine);
        }
        fromX = baseX;
        fromY = bandY;
      }

      if (edge.toIsPhrase) {
        const pn = phraseNodes.find(pn => pn.headPosition === edge.to)
               || this.findSmallestCoveringPhrase(edge.to, phraseNodes);
        const pos = pn ? phraseDotPositions.get(pn) : null;
        if (!pos) continue;
        toX = pos.x;
        toY = pos.y;
      } else {
        const baseX = positionToCenter[edge.to] ?? null;
        if (baseX === null) continue;
        const bandY = fromY !== null ? fromY : defaultBandY;
        const tok = tokensByPos[edge.to];
        if (tok) {
          this.drawDuplicateTokenBlock(svg, tok, baseX, bandY, tok.colorClass);
          const dotLine = document.createElementNS(this.SVG_NS, "path");
          dotLine.setAttribute("d", `M ${baseX},${tokenRowY - 6} L ${baseX},${bandY + DOT_R}`);
          dotLine.setAttribute("fill", "none");
          dotLine.setAttribute("stroke", "#4472C4");
          dotLine.setAttribute("stroke-width", "0.8");
          dotLine.setAttribute("stroke-dasharray", "3 2");
          svg.appendChild(dotLine);
        }
        toX = baseX;
        toY = bandY;
      }

      if (fromX === null || toX === null || fromY === null || toY === null) continue;

      const bandY = Math.min(fromY, toY);
      const apexAbsY = bandY - ARC_HEIGHT;

      const path = document.createElementNS(this.SVG_NS, "path");
      const d = `M ${fromX},${fromY} C ${fromX},${apexAbsY} ${toX},${apexAbsY} ${toX},${toY}`;
      path.setAttribute("d", d);
      path.setAttribute("fill", "none");
      path.setAttribute("stroke-width", "1.5");
      if (edge.colorClass) path.classList.add(edge.colorClass);
      svg.appendChild(path);

      const midX = (fromX + toX) / 2;
      const curveApexY = apexAbsY + (bandY - apexAbsY) * 0.25;
      const arrowSize = 6;
      const goesLeft = toX < fromX;

      const arrow = document.createElementNS(this.SVG_NS, "polygon");
      let points;
      if (goesLeft) {
        points = `${midX - arrowSize},${curveApexY} ${midX + arrowSize / 2},${curveApexY - arrowSize / 2} ${midX + arrowSize / 2},${curveApexY + arrowSize / 2}`;
      } else {
        points = `${midX + arrowSize},${curveApexY} ${midX - arrowSize / 2},${curveApexY - arrowSize / 2} ${midX - arrowSize / 2},${curveApexY + arrowSize / 2}`;
      }
      arrow.setAttribute("points", points);
      if (edge.colorClass) arrow.classList.add(edge.colorClass);
      svg.appendChild(arrow);

      if (edge.label && edge.relation) {
        const labelUrl = this.grammarUrl("edge_relations", edge.relation);
        const linkEl = document.createElementNS(this.SVG_NS, "a");
        linkEl.setAttribute("href", labelUrl);
        linkEl.setAttributeNS(this.XLINK_NS, "xlink:href", labelUrl);
        linkEl.setAttribute("data-controller", "ajax-modal");
        linkEl.setAttribute("data-url", labelUrl);

        const labelEl = document.createElementNS(this.SVG_NS, "text");
        labelEl.textContent = edge.label;
        labelEl.setAttribute("x", midX);
        labelEl.setAttribute("y", curveApexY - 6);
        labelEl.setAttribute("font-family", this.arabicFont);
        labelEl.setAttribute("font-size", this.edgeLabelFontSize);
        labelEl.setAttribute("text-anchor", "middle");
        labelEl.setAttribute("dominant-baseline", "auto");
        if (edge.colorClass) labelEl.classList.add(edge.colorClass);
        labelEl.classList.add("term-link");
        linkEl.appendChild(labelEl);
        svg.appendChild(linkEl);
      }
    }
  }

  drawTokens(svg, tokens, centers, baseY) {
    const locationY = baseY + 16;
    const arabicY = baseY + 50;
    const posY = baseY + 78;

    tokens.forEach((tok, i) => {
      const cx = centers[i];

      if (tok.location) {
        if (tok.wordUrl) {
          const linkEl = document.createElementNS(this.SVG_NS, "a");
          linkEl.setAttribute("href", tok.wordUrl);
          linkEl.setAttributeNS(this.XLINK_NS, "xlink:href", tok.wordUrl);
          const locEl = document.createElementNS(this.SVG_NS, "text");
          locEl.textContent = tok.location;
          locEl.setAttribute("x", cx);
          locEl.setAttribute("y", locationY);
          locEl.setAttribute("font-family", this.labelFont);
          locEl.setAttribute("font-size", this.locationFontSize);
          locEl.setAttribute("text-anchor", "middle");
          locEl.classList.add("treebank-location");
          linkEl.appendChild(locEl);
          svg.appendChild(linkEl);
        } else {
          const locEl = document.createElementNS(this.SVG_NS, "text");
          locEl.textContent = tok.location;
          locEl.setAttribute("x", cx);
          locEl.setAttribute("y", locationY);
          locEl.setAttribute("font-family", this.labelFont);
          locEl.setAttribute("font-size", this.locationFontSize);
          locEl.setAttribute("text-anchor", "middle");
          locEl.classList.add("treebank-location");
          svg.appendChild(locEl);
        }
      }

      const arabicEl = document.createElementNS(this.SVG_NS, "text");
      arabicEl.textContent = tok.arabic || "";
      arabicEl.setAttribute("x", cx);
      arabicEl.setAttribute("y", arabicY);
      arabicEl.setAttribute("font-family", this.arabicFont);
      arabicEl.setAttribute("font-size", this.tokenFontSize);
      arabicEl.setAttribute("text-anchor", "middle");
      arabicEl.setAttribute("dominant-baseline", "middle");
      if (tok.colorClass) arabicEl.classList.add(tok.colorClass);
      svg.appendChild(arabicEl);

      if (tok.posLabel && tok.posKey) {
        const posUrl = this.grammarUrl("pos_tags", tok.posKey);
        const linkEl = document.createElementNS(this.SVG_NS, "a");
        linkEl.setAttribute("href", posUrl);
        linkEl.setAttributeNS(this.XLINK_NS, "xlink:href", posUrl);
        linkEl.setAttribute("data-controller", "ajax-modal");
        linkEl.setAttribute("data-url", posUrl);

        const posEl = document.createElementNS(this.SVG_NS, "text");
        posEl.textContent = tok.posLabel;
        posEl.setAttribute("x", cx);
        posEl.setAttribute("y", posY);
        posEl.setAttribute("font-family", this.arabicFont);
        posEl.setAttribute("font-size", this.posLabelFontSize);
        posEl.setAttribute("text-anchor", "middle");
        posEl.setAttribute("dominant-baseline", "middle");
        if (tok.colorClass) posEl.classList.add(tok.colorClass);
        posEl.classList.add("term-link");
        linkEl.appendChild(posEl);
        svg.appendChild(linkEl);
      }
    });
  }

  drawArcs(svg, arcData, tokenRowY) {
    for (const arc of arcData) {
      const { edge, fromX, toX, apexY } = arc;
      const x1 = fromX;
      const x2 = toX;
      const y = tokenRowY;
      const apexAbsY = tokenRowY - apexY;

      const cp1x = x1;
      const cp1y = apexAbsY;
      const cp2x = x2;
      const cp2y = apexAbsY;

      const path = document.createElementNS(this.SVG_NS, "path");
      const d = `M ${x1},${y} C ${cp1x},${cp1y} ${cp2x},${cp2y} ${x2},${y}`;
      path.setAttribute("d", d);
      path.setAttribute("fill", "none");
      path.setAttribute("stroke-width", "1.5");
      if (edge.colorClass) path.classList.add(edge.colorClass);
      svg.appendChild(path);

      const midX = (x1 + x2) / 2;
      const curveApexY = apexAbsY + (y - apexAbsY) * 0.25;
      const arrowSize = 6;
      const goesLeft = toX < fromX;

      const arrow = document.createElementNS(this.SVG_NS, "polygon");
      let points;
      if (goesLeft) {
        points = `${midX - arrowSize},${curveApexY} ${midX + arrowSize / 2},${curveApexY - arrowSize / 2} ${midX + arrowSize / 2},${curveApexY + arrowSize / 2}`;
      } else {
        points = `${midX + arrowSize},${curveApexY} ${midX - arrowSize / 2},${curveApexY - arrowSize / 2} ${midX - arrowSize / 2},${curveApexY + arrowSize / 2}`;
      }
      arrow.setAttribute("points", points);
      if (edge.colorClass) arrow.classList.add(edge.colorClass);
      svg.appendChild(arrow);

      if (edge.label && edge.relation) {
        const labelUrl = this.grammarUrl("edge_relations", edge.relation);
        const linkEl = document.createElementNS(this.SVG_NS, "a");
        linkEl.setAttribute("href", labelUrl);
        linkEl.setAttributeNS(this.XLINK_NS, "xlink:href", labelUrl);
        linkEl.setAttribute("data-controller", "ajax-modal");
        linkEl.setAttribute("data-url", labelUrl);

        const labelEl = document.createElementNS(this.SVG_NS, "text");
        labelEl.textContent = edge.label;
        labelEl.setAttribute("x", midX);
        labelEl.setAttribute("y", curveApexY - 6);
        labelEl.setAttribute("font-family", this.arabicFont);
        labelEl.setAttribute("font-size", this.edgeLabelFontSize);
        labelEl.setAttribute("text-anchor", "middle");
        labelEl.setAttribute("dominant-baseline", "auto");
        if (edge.colorClass) labelEl.classList.add(edge.colorClass);
        labelEl.classList.add("term-link");
        linkEl.appendChild(labelEl);
        svg.appendChild(linkEl);
      }
    }
  }
}

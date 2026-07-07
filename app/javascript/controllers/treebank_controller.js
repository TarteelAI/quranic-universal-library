import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container", "canvas", "zoomIn", "zoomOut", "zoomReset", "download"];
  static values = {
    url: String,
  };

  connect() {
    this.zoomLevel = 1.0;
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
    const wrapper = this.containerTarget.querySelector(".treebank-zoom-wrapper");
    if (wrapper) {
      wrapper.style.transform = `scale(${this.zoomLevel})`;
      wrapper.style.transformOrigin = "top center";
    }
  }

  async loadData() {
    try {
      this.containerTarget.textContent = "Loading treebank...";
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      await this.renderAll(data);
    } catch (err) {
      console.error("Treebank load failed:", err);
      this.containerTarget.innerHTML = '<div class="text-red-500 p-4">Failed to load treebank data.</div>';
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

    document.body.removeChild(tempSvg);

    const svg = document.createElementNS(this.SVG_NS, "svg");
    svg.setAttribute("width", svgW);
    svg.setAttribute("height", svgH);
    svg.setAttribute("viewBox", `0 0 ${svgW} ${svgH}`);
    svg.setAttribute("xmlns", this.SVG_NS);
    svg.style.maxWidth = "100%";
    svg.style.display = "block";

    this.drawBanner(svg, svgW);

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
      this.drawPhraseEdges(svg, phraseEdges, phraseNodes, phraseDotPositions, positionToCenter, tokenRowY);
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

    const MIN_ARC_HEIGHT = 30;
    const ARC_STEP = 25;
    const occupiedBands = [];

    for (const arc of arcList) {
      const x1 = Math.min(arc.fromX, arc.toX);
      const x2 = Math.max(arc.fromX, arc.toX);
      let apexY = MIN_ARC_HEIGHT + arc.span * 10;

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

  drawBanner(svg, svgW) {
    const bannerText = (this.sentence.banner && this.sentence.banner.text) || "";
    const refText = (this.sentence.banner && this.sentence.banner.reference) || "";

    const bannerTextEl = document.createElementNS(this.SVG_NS, "text");
    bannerTextEl.textContent = bannerText;
    bannerTextEl.setAttribute("x", svgW / 2);
    bannerTextEl.setAttribute("y", 32);
    bannerTextEl.setAttribute("font-family", this.arabicFont);
    bannerTextEl.setAttribute("font-size", this.bannerFontSize);
    bannerTextEl.setAttribute("text-anchor", "middle");
    bannerTextEl.setAttribute("dominant-baseline", "middle");
    bannerTextEl.classList.add("treebank-banner-text");
    svg.appendChild(bannerTextEl);

    const refEl = document.createElementNS(this.SVG_NS, "text");
    refEl.textContent = refText;
    refEl.setAttribute("x", svgW / 2);
    refEl.setAttribute("y", 56);
    refEl.setAttribute("font-family", this.arabicFont);
    refEl.setAttribute("font-size", this.bannerRefFontSize);
    refEl.setAttribute("text-anchor", "middle");
    refEl.setAttribute("dominant-baseline", "middle");
    refEl.classList.add("treebank-banner-ref");
    svg.appendChild(refEl);

    const underline = document.createElementNS(this.SVG_NS, "line");
    underline.setAttribute("x1", this.padding);
    underline.setAttribute("y1", this.bannerHeight - 4);
    underline.setAttribute("x2", svgW - this.padding);
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
    for (const tok of tokens) {
      if (coveredPositions.has(tok.position)) continue;
      const tokX = positionToCenter[tok.position];
      if (tokX !== undefined) this.phraseConnectorPath(svg, tokX, topTokenY, bannerAnchorX, bannerAnchorY);
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

  drawPhraseEdges(svg, phraseEdges, phraseNodes, phraseDotPositions, positionToCenter, tokenRowY) {
    const PHRASE_ARC_Y = this.bannerHeight + this.phraseLevelHeight * 0.5;
    const ARC_APEX_ABOVE = 20;

    for (const edge of phraseEdges) {
      let fromX = null;
      let fromY = PHRASE_ARC_Y;
      let toX = null;
      let toY = PHRASE_ARC_Y;

      if (edge.fromIsPhrase) {
        const pn = this.findSmallestCoveringPhrase(edge.from, phraseNodes);
        const pos = pn ? phraseDotPositions.get(pn) : null;
        if (!pos) continue;
        fromX = pos.x;
        fromY = pos.y;
      } else {
        fromX = positionToCenter[edge.from] ?? null;
        fromY = tokenRowY - 6;
      }

      if (edge.toIsPhrase) {
        const pn = this.findSmallestCoveringPhrase(edge.to, phraseNodes);
        const pos = pn ? phraseDotPositions.get(pn) : null;
        if (!pos) continue;
        toX = pos.x;
        toY = pos.y;
      } else {
        toX = positionToCenter[edge.to] ?? null;
        toY = tokenRowY - 6;
      }

      if (fromX === null || toX === null) continue;

      const apexY = Math.min(fromY, toY) - ARC_APEX_ABOVE;

      const path = document.createElementNS(this.SVG_NS, "path");
      const d = `M ${fromX},${fromY} C ${fromX},${apexY} ${toX},${apexY} ${toX},${toY}`;
      path.setAttribute("d", d);
      path.setAttribute("fill", "none");
      path.setAttribute("stroke-width", "1.5");
      if (edge.colorClass) path.classList.add(edge.colorClass);
      svg.appendChild(path);

      const midX = (fromX + toX) / 2;
      const midY = apexY + (Math.max(fromY, toY) - apexY) * 0.5;
      const arrowSize = 6;
      const goesLeft = toX < fromX;

      const arrow = document.createElementNS(this.SVG_NS, "polygon");
      let points;
      if (goesLeft) {
        points = `${midX - arrowSize},${midY} ${midX + arrowSize / 2},${midY - arrowSize / 2} ${midX + arrowSize / 2},${midY + arrowSize / 2}`;
      } else {
        points = `${midX + arrowSize},${midY} ${midX - arrowSize / 2},${midY - arrowSize / 2} ${midX - arrowSize / 2},${midY + arrowSize / 2}`;
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
        labelEl.setAttribute("y", apexY - 6);
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
      const midY = apexAbsY + (y - apexAbsY) * 0.5;
      const arrowSize = 6;
      const goesLeft = toX < fromX;

      const arrow = document.createElementNS(this.SVG_NS, "polygon");
      let points;
      if (goesLeft) {
        points = `${midX - arrowSize},${midY} ${midX + arrowSize / 2},${midY - arrowSize / 2} ${midX + arrowSize / 2},${midY + arrowSize / 2}`;
      } else {
        points = `${midX + arrowSize},${midY} ${midX - arrowSize / 2},${midY - arrowSize / 2} ${midX - arrowSize / 2},${midY + arrowSize / 2}`;
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
        labelEl.setAttribute("y", apexAbsY - 6);
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

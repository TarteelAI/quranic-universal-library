import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container"];
  static values = {
    graphData: Object,
    theme: Object,
    url: String,
  };

  connect() {
    if (this.hasUrlValue) {
      this.loadGraphData();
    } else if (this.graphDataValue) {
      this.renderSyntaxGraph();
    }

    // Listen for refresh events
    this.refreshHandler = () => this.refresh();
    window.addEventListener("refresh-graph-preview", this.refreshHandler);
  }

  disconnect() {
    if (this.refreshHandler) {
      window.removeEventListener("refresh-graph-preview", this.refreshHandler);
    }
  }

  refresh() {
    if (this.hasUrlValue) {
      this.loadGraphData();
    }
  }

  async loadGraphData() {
    try {
      this.containerTarget.textContent = "Loading syntax graph...";
      const res = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      this.graphDataValue = data;
      this.renderSyntaxGraph();
    } catch (error) {
      console.error("Failed to load syntax graph:", error);
      this.containerTarget.innerHTML =
        '<div class="error">Failed to load syntax graph</div>';
    }
  }

  // graphDataValueChanged() {
  //   console.log("Graph data changed");
  //   this.renderSyntaxGraph();
  // }

  async renderSyntaxGraph() {
    try {
      const visualizer = new SyntaxGraphVisualizer(
        this.graphDataValue,
        this.getTheme()
      );
      const svg = await visualizer.renderGraph();
      this.containerTarget.innerHTML = "";
      this.containerTarget.appendChild(svg);
    } catch (error) {
      console.error("Error rendering syntax graph:", error);
      this.containerTarget.innerHTML =
        '<div class="error">Error rendering syntax graph</div>';
    }
  }

  getTheme() {
    const defaultTheme = {
      fonts: {
        defaultFont: { family: "Helvetica Neue, Arial, sans-serif" },
        defaultArabicFont: {
          family: "qpc-hafs, Arial Unicode MS, sans-serif",
        },
        elidedWordFont: { family: "Arial, sans-serif" },
      },
      syntaxGraphTokenFontSize: 34,
      syntaxGraphTagFontSize: 12,
      syntaxGraphHeaderFontSize: 10,
      syntaxGraphElidedWordFontSize: 22,
      syntaxGraphEdgeLabelFontSize: 13,
    };

    if (!this.themeValue) return defaultTheme;

    return {
      ...defaultTheme,
      ...this.themeValue,
      fonts: {
        ...defaultTheme.fonts,
        ...(this.themeValue.fonts || {}),
      },
    };
  }
}
class SyntaxGraphVisualizer {
  constructor(syntaxGraph, theme) {
    this.syntaxGraph = syntaxGraph;
    this.syntaxGraph.segmentNodeCount = syntaxGraph.words.reduce(
      (sum, word) => sum + (word.endNode - word.startNode + 1),
      0
    );
    this.theme = theme;
    this.colorService = new ColorService();
    this.heightMap = new HeightMap();
    this.phraseLayouts = [];
    this.nodePositions = [];

    this.arabicTerms = new Map([
      ["adj", "صفة"],
      ["amd", "استدراك"],
      ["ans", "جواب"],
      ["app", "بدل"],
      ["avr", "ردع"],
      ["caus", "سببية"],
      ["cert", "تحقيق"],
      ["circ", "حال"],
      ["cog", "مفعول مطلق"],
      ["com", "مفعول معه"],
      ["cond", "شرط"],
      ["conj", "معطوف"],
      ["cpnd", "مركب"],
      ["emph", "توكيد"],
      ["eq", "تسوية"],
      ["exh", "تحضيض"],
      ["exl", "تفصيل"],
      ["exp", "مستثني"],
      ["fut", "استقبال"],
      ["gen", "مجرور"],
      ["impv", "أمر"],
      ["imrs", "جواب أمر"],
      ["inc", "ابتداء"],
      ["int", "تفسير"],
      ["intg", "استفهام"],
      ["link", "متعلق"],
      ["neg", "نفي"],
      ["obj", "مفعول به"],
      ["pass", "نائب فاعل"],
      ["poss", "مضاف إليه"],
      ["pred", "خبر"],
      ["prev", "كاف"],
      ["pro", "نهي"],
      ["prp", "مفعول لأجله"],
      ["res", "حصر"],
      ["ret", "اضراب"],
      ["rslt", "جواب شرط"],
      ["spec", "تمييز"],
      ["sub", "صلة"],
      ["subj", "فاعل"],
      ["sup", "زائد"],
      ["sur", "فجاءة"],
      ["voc", "منادي"],
    ]);

    this.subject = "اسم";
    this.predicate = "خبر";
  }

  async renderGraph() {
    await this.loadFonts();
    const layout = this.layoutGraph();
    return this.renderSVG(layout);
  }

  async loadFonts() {
    const fonts = [
      this.theme.fonts.defaultFont.family,
      this.theme.fonts.defaultArabicFont.family,
      this.theme.fonts.elidedWordFont.family,
    ];

    for (const fontFamily of fonts) {
      try {
        const style = `1em ${fontFamily}`;
        await document.fonts.load(style);
        const loaded = document.fonts.check(style);
        if (!loaded) {
          console.warn(`Failed to load font ${fontFamily}`);
        }
      } catch (error) {
        console.warn(`Error loading font ${fontFamily}:`, error);
      }
    }
  }

  layoutGraph() {
    const { words } = this.syntaxGraph;

    // Create temporary SVG for text measurement
    const tempSvg = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "svg"
    );
    tempSvg.style.position = "absolute";
    tempSvg.style.visibility = "hidden";
    document.body.appendChild(tempSvg);
    const wordLayouts = words.map((word, i) => {
      const brackets = this.brackets(word);
      return {
        location: this.createBox(
          word.token ? word.token.location || "" : "",
          tempSvg,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize
        ),
        phonetic: this.createBox(
          word.token ? word.token.phonetic || "" : "",
          tempSvg,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize
        ),
        translation: this.createBox(
          word.token ? word.token.translation || "" : "",
          tempSvg,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize
        ),
        bra: brackets
          ? this.createBox(
              ")",
              tempSvg,
              this.theme.fonts.elidedWordFont,
              this.theme.syntaxGraphElidedWordFontSize
            )
          : undefined,
        token: this.createBox(
          this.getTokenText(word),
          tempSvg,
          this.theme.fonts.defaultArabicFont,
          this.theme.syntaxGraphTokenFontSize
        ),
        ket: brackets
          ? this.createBox(
              ")",
              tempSvg,
              this.theme.fonts.elidedWordFont,
              this.theme.syntaxGraphElidedWordFontSize
            )
          : undefined,
        nodeCircles: [],
        posTags: this.getPosTagTexts(word).map((text) =>
          this.createBox(
            text,
            tempSvg,
            this.theme.fonts.defaultFont,
            this.theme.syntaxGraphTagFontSize
          )
        ),
        bounds: { x: 0, y: 0, width: 0, height: 0 },
      };
    });
    for (let i = 0; i < words.length; i++) {
      this.layoutWord(words[i], wordLayouts[i]);
    }

    const wordGap = 63;
    const containerWidth = this.getTotalWidth(
      wordLayouts.map((layout) => layout.bounds),
      wordGap
    );
    const segmentNodeY =
      Math.max(...wordLayouts.map((layout) => layout.bounds.height)) + 5;
    this.heightMap.addSpan(0, containerWidth, segmentNodeY);

    let x = containerWidth;
    for (const layout of wordLayouts) {
      x -= layout.bounds.width;
      this.positionWord(layout, x, 0);
      x -= wordGap;

      for (const nodeCircle of layout.nodeCircles) {
        this.nodePositions.push({ x: nodeCircle.cx, y: segmentNodeY });
      }
    }

    if (this.syntaxGraph.phraseNodes) {
      for (const phraseNode of this.syntaxGraph.phraseNodes) {
        this.phraseLayouts.push({
          line: { x1: 0, y1: 0, x2: 0, y2: 0 },
          nodeCircle: { cx: 0, cy: 0, r: 0 },
          phraseTag: this.createBox(
            phraseNode.phraseTag,
            tempSvg,
            this.theme.fonts.defaultFont,
            this.theme.syntaxGraphTagFontSize
          ),
        });
      }
    }

    const edgeLabels = (this.syntaxGraph.edges || []).map((edge) => {
      const label = this.getEdgeLabel(edge);
      return this.createBox(
        label,
        tempSvg,
        this.theme.fonts.defaultArabicFont,
        this.theme.syntaxGraphEdgeLabelFontSize
      );
    });

    const arcs = [];
    const arrows = [];
    const { edges } = this.syntaxGraph;
    if (edges) {
      for (let i = 0; i < edges.length; i++) {
        const { startNode, endNode } = edges[i];

        const start =
          this.nodePositions[startNode] ?? this.layoutPhrase(startNode);
        const end = this.nodePositions[endNode] ?? this.layoutPhrase(endNode);

        const right = start.x < end.x;
        const { x: x1, y: y1 } = right ? start : end;
        const { x: x2, y: y2 } = right ? end : start;

        const boxWidth = x2 - x1;
        let y = Math.min(y1, y2);
        const deltaY = Math.abs(y2 - y1);

        const maxY = this.heightMap.getHeight(x1 + 5, x2 - 5);
        let boxHeight = deltaY + 30;
        while (y + boxHeight < maxY) {
          boxHeight += 50;
        }

        const ry = boxHeight;
        const theta = Math.asin(deltaY / ry);
        const rx = boxWidth / (1 + Math.cos(theta));
        arcs.push({ x1, y1, x2, y2, rx, ry });
        y += boxHeight;

        const maximaX = y2 > y1 ? x1 + rx : x2 - rx;
        arrows.push({ x: maximaX - 3, y: y - 5, right });

        const edgeLabel = edgeLabels[i];
        y += 5;
        edgeLabel.x = maximaX - edgeLabel.width * 0.5;
        edgeLabel.y = y;
        this.heightMap.addSpan(x1, x2, y + edgeLabel.height);
      }
    }

    const actualWidth = containerWidth * 1.5; // 50% buffer to ensure no cutoff

    document.body.removeChild(tempSvg);

    return {
      wordLayouts,
      phraseLayouts: this.phraseLayouts,
      edgeLabels,
      arcs,
      arrows,
      containerSize: {
        width: Math.ceil(actualWidth),
        height: Math.ceil(this.heightMap.height),
      },
      originalWidth: Math.ceil(containerWidth), // For viewBox
    };
  }

  layoutWord(word, layout) {
    const {
      bounds,
      location,
      phonetic,
      translation,
      bra,
      token,
      ket,
      nodeCircles,
      posTags,
    } = layout;
    const headerTextDeltaY = 15; // React uses 23, not 15
    const posTagGap = 25;
    const bracketDeltaY = 16;
    let y = 0;

    const posTagWidth = this.getTotalWidth(posTags, posTagGap);
    const brackets = this.brackets(word);
    const tokenWidth = brackets
      ? bra.width + token.width + ket.width
      : token.width;
    const width = Math.max(
      location.width,
      phonetic.width,
      translation.width,
      tokenWidth,
      posTagWidth
    );

    this.centerHorizontal(location, width, y);
    y += headerTextDeltaY;
    this.centerHorizontal(phonetic, width, y);
    y += headerTextDeltaY;
    this.centerHorizontal(translation, width, y);
    y += headerTextDeltaY + 10; // React uses +7, not +10

    let x = (width + tokenWidth) / 2;
    if (brackets) {
      x -= ket.width;
      ket.x = x + 12; // React doesn't add +12 offset
      ket.y = y + bracketDeltaY;
    }
    x -= token.width;
    token.x = x;
    token.y = y - 20; // React puts token at y, not y - 20
    if (brackets) {
      x -= bra.width;
      bra.x = x;
      bra.y = y + bracketDeltaY;
    }

    if (!word.token && !word.elidedText) {
      token.y += bracketDeltaY;
    }
    y += 65;

    let tagX = (width + posTagWidth) / 2;
    const r = 3;
    for (const posTag of posTags) {
      tagX -= posTag.width;
      nodeCircles.push({ cx: tagX + posTag.width / 2, cy: y, r });
      posTag.x = tagX + posTag.width / 2;
      posTag.y = y + 10;
      tagX -= posTagGap;
    }

    bounds.width = width;
    bounds.height = Math.max(...posTags.map((tag) => tag.y + tag.height));
  }

  positionWord(layout, x, y) {
    layout.bounds.x = x;
    layout.bounds.y = y;
    layout.location.x += x;
    layout.location.y += y;
    layout.phonetic.x += x;
    layout.phonetic.y += y;
    layout.translation.x += x;
    layout.translation.y += y;
    if (layout.bra) {
      layout.bra.x += x;
      layout.bra.y += y;
    }
    layout.token.x += x;
    layout.token.y += y;
    if (layout.ket) {
      layout.ket.x += x;
      layout.ket.y += y;
    }

    for (const nodeCircle of layout.nodeCircles) {
      nodeCircle.cx += x;
      nodeCircle.cy += y;
    }

    for (const posTag of layout.posTags) {
      posTag.x += x;
      posTag.y += y;
    }
  }

  layoutPhrase(node) {
    const { startNode, endNode } = this.getPhraseNode(node);
    const x1 = this.nodePositions[endNode].x;
    const x2 = this.nodePositions[startNode].x;
    let y = this.heightMap.getHeight(x1, x2) + 20;
    const x = (x1 + x2) / 2;

    // Line
    const phraseIndex = node - this.syntaxGraph.segmentNodeCount;
    const layout = this.phraseLayouts[phraseIndex];
    layout.line = { x1, y1: y, x2, y2: y };
    y += 13;

    // Node
    layout.nodeCircle = { cx: x, cy: y, r: 3 };
    y += 10;

    // Phrase
    const phraseTag = layout.phraseTag;
    phraseTag.x = x + 8;
    phraseTag.y = y;

    // Node
    y += phraseTag.height + 4;
    const position = { x, y };
    this.nodePositions[node] = position;
    this.heightMap.addSpan(x1, x2, y);
    return position;
  }

  getTotalWidth(elements, gap) {
    return (
      elements.reduce((totalWidth, element) => totalWidth + element.width, 0) +
      gap * (elements.length - 1)
    );
  }

  centerHorizontal(element, width, y) {
    // element.x = element.width / 2 + 15;
    element.x = (width + element.width) / 2;
    element.y = y;
  }

  createBox(
    text,
    tempSvg,
    font = this.theme.fonts.defaultFont,
    fontSize = this.theme.syntaxGraphTagFontSize
  ) {
    if (!text) {
      return { x: 0, y: 0, width: 0, height: 0 };
    }

    const textElement = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "text"
    );
    textElement.textContent = text;
    textElement.setAttribute("font-family", font.family);
    textElement.setAttribute("font-size", fontSize);

    try {
      tempSvg.appendChild(textElement);
      const bbox = textElement.getBBox();

      const result = {
        x: bbox.x || 0,
        y: bbox.y || 0,
        width: bbox.width || 0,
        height: bbox.height || 0,
      };

      if (textElement.parentNode === tempSvg) {
        tempSvg.removeChild(textElement);
      }

      return result;
    } catch (error) {
      console.warn("Error measuring text:", text, error);
      return {
        x: 0,
        y: 0,
        width: text.length * fontSize * 0.6,
        height: fontSize,
      };
    }
  }

  brackets(word) {
    return (
      word.type === "reference" || (word.type === "elided" && word.elidedText)
    );
  }

  getPhraseNode(node) {
    return this.syntaxGraph.phraseNodes[
      node - this.syntaxGraph.segmentNodeCount
    ];
  }

  getTokenText(word) {
    if (word.token) {
      return word.token.segments.map((seg) => seg.arabic).join("");
    } else if (word.elidedText) {
      return word.elidedText;
    } else {
      return "(*)";
    }
  }

  getPosTagTexts(word) {
    if (word.token) {
      return word.token.segments
        .filter((segment) => segment.posTag !== "DET")
        .map((segment) => segment.posTag);
    } else {
      return [word.elidedPosTag || "ELIDED"];
    }
  }

  getEdgeLabel(edge) {
    const { dependencyTag, endNode: headNode } = edge;
    if (dependencyTag !== "subjx" && dependencyTag !== "predx") {
      return this.arabicTerms.get(dependencyTag) || "?";
    }

    const name = dependencyTag === "subjx" ? this.subject : this.predicate;
    const headWord = this.syntaxGraph.words.find(
      (word) => headNode >= word.startNode && headNode <= word.endNode
    );

    if (headWord && headWord.token) {
      const headSegment = headWord.token.segments.find(
        (segment) => segment.nodeNumber === headNode
      );
      if (headSegment && headSegment.posTag === "V") {
        return name;
      }
    }

    return this.arabicTerms.get(dependencyTag) || "?";
  }

  renderSVG(layout) {
    const {
      wordLayouts,
      phraseLayouts,
      edgeLabels,
      arcs,
      arrows,
      containerSize,
      originalWidth,
    } = layout;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", containerSize.width);
    svg.setAttribute("height", containerSize.height);
    svg.setAttribute("viewBox", `0 0 ${originalWidth} ${containerSize.height}`);
    svg.classList.add("syntax-graph-view");

    // Render words using new layout structure
    this.syntaxGraph.words.forEach((word, i) => {
      const wordLayout = wordLayouts[i];
      const fade = word.type === "reference";
      const brackets = this.brackets(word);

      // Header text
      if (word.token) {
        this.addText(
          svg,
          word.token.location || "",
          wordLayout.location,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize,
          fade ? "silver" : "location"
        );
        this.addText(
          svg,
          word.token.phonetic || "",
          wordLayout.phonetic,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize,
          fade ? "silver" : "phonetic"
        );
        this.addText(
          svg,
          word.token.translation || "",
          wordLayout.translation,
          this.theme.fonts.defaultFont,
          this.theme.syntaxGraphHeaderFontSize,
          fade ? "silver" : ""
        );
      }

      // Brackets
      if (brackets && wordLayout.bra) {
        this.addText(
          svg,
          ")",
          wordLayout.bra,
          this.theme.fonts.elidedWordFont,
          this.theme.syntaxGraphElidedWordFontSize,
          "silver"
        );
      }

      // Token - render as single text or with tspan segments
      if (word.token && word.token.segments) {
        const textElement = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "text"
        );
        const fontMetrics = this.getFontMetrics(
          this.theme.fonts.defaultArabicFont
        );
        const y =
          wordLayout.token.y +
          wordLayout.token.height -
          fontMetrics.descenderHeight * this.theme.syntaxGraphTokenFontSize;
        const x = wordLayout.token.x + wordLayout.token.width;

        textElement.setAttribute("x", x);
        textElement.setAttribute("y", y);
        textElement.setAttribute(
          "font-family",
          this.theme.fonts.defaultArabicFont.family
        );
        textElement.setAttribute(
          "font-size",
          this.theme.syntaxGraphTokenFontSize
        );
        textElement.setAttribute("direction", "rtl");

        word.token.segments.forEach((segment) => {
          const tspan = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "tspan"
          );
          tspan.textContent = segment.arabic;
          const segmentClassName = fade
            ? "silver"
            : this.colorService.getSegmentColor(segment);
          if (segmentClassName) tspan.classList.add(segmentClassName);
          textElement.appendChild(tspan);
        });

        svg.appendChild(textElement);
      } else {
        // Elided or simple token
        const tokenText = this.getTokenText(word);
        const isElided = !word.token;
        const font =
          isElided && tokenText === "(*)"
            ? this.theme.fonts.elidedWordFont
            : this.theme.fonts.defaultArabicFont;
        const fontSize =
          isElided && tokenText === "(*)"
            ? this.theme.syntaxGraphElidedWordFontSize
            : this.theme.syntaxGraphTokenFontSize;
        this.addText(
          svg,
          tokenText,
          wordLayout.token,
          font,
          fontSize,
          "silver",
          true
        );
      }

      // Brackets
      if (brackets && wordLayout.ket) {
        this.addText(
          svg,
          "(",
          wordLayout.ket,
          this.theme.fonts.elidedWordFont,
          this.theme.syntaxGraphElidedWordFontSize,
          "silver"
        );
      }

      // POS tags and node circles
      const posTagTexts = this.getPosTagTexts(word);
      posTagTexts.forEach((posTagText, j) => {
        const nodeCircle = wordLayout.nodeCircles[j];
        const posTag = wordLayout.posTags[j];
        const className = fade
          ? "silver"
          : this.colorService.getPosTagColor(posTagText);

        if (nodeCircle) {
          this.addCircle(svg, nodeCircle, className);
        }
        if (posTag) {
          this.addText(
            svg,
            posTagText,
            posTag,
            this.theme.fonts.defaultFont,
            this.theme.syntaxGraphTagFontSize,
            className
          );
        }
      });
    });

    // Render phrase nodes
    if (this.syntaxGraph.phraseNodes) {
      this.syntaxGraph.phraseNodes.forEach((phraseNode, i) => {
        const phraseLayout = phraseLayouts[i];
        const className = this.colorService.getPhraseColor(
          phraseNode.phraseTag
        );

        if (phraseLayout) {
          this.addLine(svg, phraseLayout.line, "sky-light");
          this.addCircle(svg, phraseLayout.nodeCircle, className);
          this.addText(
            svg,
            phraseNode.phraseTag,
            phraseLayout.phraseTag,
            this.theme.fonts.defaultFont,
            this.theme.syntaxGraphTagFontSize,
            className
          );
        }
      });
    }

    // Render arcs and arrows
    if (this.syntaxGraph.edges) {
      this.syntaxGraph.edges.forEach((edge, i) => {
        const arc = arcs[i];
        if (arc) {
          const className = `${this.colorService.getDependencyColor(edge.dependencyTag)}-light`;
          this.addArc(svg, arc, className);
          this.addArrow(svg, arrows[i], className);
        }
      });

      // Render edge labels with Arabic terms
      this.syntaxGraph.edges.forEach((edge, i) => {
        const edgeLabel = edgeLabels[i];
        const className = `${this.colorService.getDependencyColor(edge.dependencyTag)}-light`;

        if (edgeLabel) {
          this.addRect(svg, edgeLabel, "edge-label");
          this.addText(
            svg,
            this.getEdgeLabel(edge),
            edgeLabel,
            this.theme.fonts.defaultFont,
            this.theme.syntaxGraphEdgeLabelFontSize,
            className
          );
        }
      });
    }

    return svg;
  }

  brackets(word) {
    return (
      word.type === "reference" || (word.type === "elided" && word.elidedText)
    );
  }

  addText(svg, text, box, font, fontSize, className = "", rtl = false) {
    if (!box || !text) return;

    const textElement = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "text"
    );
    textElement.textContent = text;

    const fontMetrics = this.getFontMetrics(font);
    const y = box.y + box.height - fontMetrics.descenderHeight * fontSize;
    const x = rtl ? box.x + box.width : box.x;

    textElement.setAttribute("x", x);
    textElement.setAttribute("y", y);
    textElement.setAttribute("font-family", font.family);
    textElement.setAttribute("font-size", fontSize);
    if (className) textElement.classList.add(className);
    if (rtl) textElement.setAttribute("direction", "rtl");

    svg.appendChild(textElement);
  }

  getFontMetrics(font) {
    // Approximate font metrics - React uses actual font service
    return {
      descenderHeight: 0.1, // Approximate descender height ratio
    };

    // Use canvas-based measurement like React FontService
    if (!this.fontMetricsCache) {
      this.fontMetricsCache = new Map();
    }

    const fontKey = font.family;
    if (this.fontMetricsCache.has(fontKey)) {
      return this.fontMetricsCache.get(fontKey);
    }

    // Create canvas for measurement
    if (!this.metricsCanvas) {
      this.metricsCanvas = document.createElement("canvas");
      this.metricsContext = this.metricsCanvas.getContext("2d");
    }

    // Measure font metrics using canvas
    const fontSize = 100;
    this.metricsContext.font = `${fontSize}px ${font.family}`;
    const textMetrics = this.metricsContext.measureText("abc");

    const fontMetrics = {
      descenderHeight: textMetrics.fontBoundingBoxDescent / fontSize,
    };

    // Cache the result
    this.fontMetricsCache.set(fontKey, fontMetrics);
    return fontMetrics;
  }

  addCircle(svg, circle, className) {
    const circleElement = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "circle"
    );
    circleElement.setAttribute("cx", circle.cx);
    circleElement.setAttribute("cy", circle.cy);
    circleElement.setAttribute("r", circle.r);
    if (className) circleElement.classList.add(className);
    svg.appendChild(circleElement);
  }

  addLine(svg, line, className) {
    const lineElement = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "line"
    );
    lineElement.setAttribute("x1", line.x1);
    lineElement.setAttribute("y1", line.y1);
    lineElement.setAttribute("x2", line.x2);
    lineElement.setAttribute("y2", line.y2);
    if (className) lineElement.classList.add(className);
    svg.appendChild(lineElement);
  }

  addRect(svg, rect, className) {
    const rectElement = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "rect"
    );
    rectElement.setAttribute("x", rect.x);
    rectElement.setAttribute("y", rect.y);
    rectElement.setAttribute("width", rect.width);
    rectElement.setAttribute("height", rect.height);
    if (className) rectElement.classList.add(className);
    svg.appendChild(rectElement);
  }

  addArc(svg, arc, className) {
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    const d = `M ${arc.x1} ${arc.y1} A ${arc.rx} ${arc.ry} 0 0 0 ${arc.x2} ${arc.y2}`;
    path.setAttribute("d", d);
    path.setAttribute("fill", "none");
    if (className) path.classList.add(className);
    svg.appendChild(path);
  }

  addArrow(svg, arrow, className) {
    const polygon = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "polygon"
    );
    const { x, y, right } = arrow;
    const points = right
      ? `${x},${y} ${x},${y + 10} ${x + 6},${y + 5}`
      : `${x + 6},${y} ${x + 6},${y + 10} ${x},${y + 5}`;
    polygon.setAttribute("points", points);
    if (className) polygon.classList.add(className);
    svg.appendChild(polygon);
  }
}

class HeightMap {
  constructor() {
    this.spans = [];
  }

  get height() {
    return this.spans.reduce((max, span) => Math.max(max, span.height), 0);
  }

  getHeight(x1, x2) {
    x1 += 5;
    x2 -= 5;

    let max = 0;
    for (const span of this.spans) {
      if (x1 <= span.x2 && x2 >= span.x1 && span.height > max) {
        max = span.height;
      }
    }
    return max;
  }

  addSpan(x1, x2, height) {
    this.spans.push({ x1, x2, height });
  }
}

class ColorService {
  constructor() {
    this.posTagColors = new Map([
      ["ADJ", "purple"],
      ["CIRC", "navy"],
      ["COM", "navy"],
      ["COND", "orange"],
      ["CONJ", "navy"],
      ["DEM", "brown"],
      ["DET", "gray"],
      ["INL", "orange"],
      ["INTG", "rose"],
      ["LOC", "orange"],
      ["N", "sky"],
      ["NEG", "red"],
      ["PN", "blue"],
      ["P", "rust"],
      ["PREV", "orange"],
      ["PRP", "gold"],
      ["PRO", "red"],
      ["REL", "gold"],
      ["REM", "navy"],
      ["RSLT", "navy"],
      ["SUB", "gold"],
      ["T", "orange"],
      ["V", "seagreen"],
      ["VOC", "green"],
    ]);

    this.phraseTagColors = new Map([
      ["CS", "orange"],
      ["PP", "rust"],
      ["SC", "gold"],
      ["VS", "seagreen"],
    ]);

    this.dependencyTagColors = new Map([
      ["adj", "purple"],
      ["app", "sky"],
      ["circ", "seagreen"],
      ["cog", "seagreen"],
      ["com", "metal"],
      ["cond", "orange"],
      ["cpnd", "sky"],
      ["gen", "rust"],
      ["int", "orange"],
      ["intg", "rose"],
      ["link", "orange"],
      ["neg", "red"],
      ["obj", "metal"],
      ["pass", "sky"],
      ["poss", "sky"],
      ["pred", "metal"],
      ["predx", "metal"],
      ["prev", "orange"],
      ["pro", "red"],
      ["prp", "metal"],
      ["spec", "metal"],
      ["spec", "sky"],
      ["sub", "gold"],
      ["subj", "sky"],
      ["subjx", "sky"],
      ["voc", "green"],
    ]);
  }

  getSegmentColor(segment) {
    const { posTag } = segment;
    const color = this.posTagColors.get(posTag);
    if (color) {
      return color;
    }
    if (posTag === "PRON") {
      switch (segment.pronounType) {
        case "subj":
          return "sky";
        case "obj2":
          return "orange";
        default:
          return "metal";
      }
    }
    return "pink";
  }

  getPhraseColor(phraseTag) {
    return this.phraseTagColors.get(phraseTag) || "blue";
  }

  getDependencyColor(dependencyTag) {
    return this.dependencyTagColors.get(dependencyTag) || "pink";
  }

  getPosTagColor(posTag) {
    const color = this.posTagColors.get(posTag);
    if (color) return color;

    if (posTag === "PRON") {
      return "red"; // Default for pronouns
    }

    return "purple";
  }
}

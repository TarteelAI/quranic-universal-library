class AyahPlayer extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });

    this.audioURL = "";
    this.audioID = "";
    this.ayahs = [];
    this.currentAyah = null;
    this.currentWordId = null;

    this.audioElement = document.createElement("audio");
    this.audioElement.controls = true;
    this.audioElement.addEventListener("timeupdate", () => this.updateHighlight());
  }

  static get observedAttributes() {
    return ["audio-url", "audio-id"];
  }

  async connectedCallback() {
    this.render();
    await this.fetchSegments();
  }

  async attributeChangedCallback(name, oldValue, newValue) {
    if (name === "audio-url") {
      this.audioURL = newValue;
      this.audioElement.src = this.audioURL;
    } else if (name === "audio-id") {
      this.audioID = newValue;
      await this.fetchSegments();
    }
  }

  async fetchSegments() {
    if (!this.audioID) return;

    try {
      const response = await fetch(`/api/segments/${this.audioID}`);
      const data = await response.json();
      this.ayahs = data || [];
      this.render();
    } catch (error) {
      console.error("Error fetching segments:", error);
    }
  }

  // **Binary Search to find the currently playing Ayah**
  findCurrentAyah(currentTime) {
    let left = 0, right = this.ayahs.length - 1;
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const ayah = this.ayahs[mid];

      if (currentTime >= ayah.start && currentTime <= ayah.ends) {
        return ayah;
      } else if (currentTime < ayah.start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return null;
  }

  // **Binary Search to find the currently playing Word**
  findCurrentWord(segments, currentTime) {
    let left = 0, right = segments.length - 1;
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const [wordId, startTime, endTime] = segments[mid];

      if (currentTime >= startTime && currentTime <= endTime) {
        return wordId;
      } else if (currentTime < startTime) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return null;
  }

  updateHighlight() {
    const currentTime = this.audioElement.currentTime * 1000; // Convert to milliseconds

    // Find the currently playing Ayah using binary search
    const newAyah = this.findCurrentAyah(currentTime);
    if (newAyah !== this.currentAyah) {
      this.currentAyah = newAyah;
      this.autoScrollToAyah();
    }

    // Find the currently playing Word within the Ayah using binary search
    if (this.currentAyah) {
      this.currentWordId = this.findCurrentWord(this.currentAyah.segments, currentTime);
    } else {
      this.currentWordId = null;
    }

    this.render();
  }

  autoScrollToAyah() {
    if (this.currentAyah) {
      setTimeout(() => {
        const ayahElement = this.shadowRoot.querySelector(`#ayah-${this.currentAyah.ayah}`);
        if (ayahElement) {
          ayahElement.scrollIntoView({ behavior: "smooth", block: "center" });
        }
      }, 100); // Delay to allow UI to update before scrolling
    }
  }

  // **Seek Audio when clicking on a word**
  seekAudio(wordId) {
    if (!this.currentAyah) return;

    const wordSegment = this.currentAyah.segments.find(([id]) => id === wordId);
    if (wordSegment) {
      const [_, startTime] = wordSegment;
      this.audioElement.currentTime = startTime / 1000; // Convert to seconds
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        .ayah-text {
          font-size: 24px;
          text-align: center;
          margin-top: 10px;
        }
        .highlighted {
          background-color: yellow;
          padding: 2px 5px;
          border-radius: 5px;
        }
        .ayah-container {
          text-align: center;
          margin-bottom: 10px;
        }
        .word {
          cursor: pointer;
          transition: background-color 0.3s;
        }
        .word:hover {
          background-color: lightgray;
        }
      </style>
      <div class="ayah-player">
        ${this.audioElement.outerHTML}
        <div class="ayah-container">
          ${this.ayahs
      .map(
        (ayah) => `
                <div id="ayah-${ayah.ayah}" class="ayah-text">
                  <strong>Ayah ${ayah.ayah}:</strong> 
                  ${ayah.words
          .map(
            (word) =>
              `<span class="word ${this.currentWordId === word.id ? "highlighted" : ""}" 
                               data-word-id="${word.id}">${word.text}</span>`
          )
          .join(" ")}
                </div>`
      )
      .join("")}
        </div>
      </div>
    `;

    this.shadowRoot.querySelector("audio").replaceWith(this.audioElement);

    // Attach event listeners to words for seeking
    this.shadowRoot.querySelectorAll(".word").forEach((wordElement) => {
      wordElement.addEventListener("click", (event) => {
        const wordId = parseInt(event.target.dataset.wordId, 10);
        this.seekAudio(wordId);
      });
    });
  }
}

customElements.define("ayah-player", AyahPlayer);

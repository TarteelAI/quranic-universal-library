import {Controller} from "@hotwired/stimulus";
import {Howl} from "howler";
import {QuranUtils} from "../utils/quran";

export default class extends Controller {
  static targets = [
    "playButton",
    "progress",
    "currentTime",
    "totalDuration"
  ];

  async connect() {
    const {recitation, verseKey} = this.element.dataset;

    this.currentChapter = QuranUtils.getSurahNumberFromVerseKey(verseKey);
    this.currentVerseNumber = QuranUtils.getAyahNumberFromVerseKey(verseKey);
    this.currentVerseKey = verseKey;

    this.recitation = recitation;
    this.verses = {};
    this.segmentsData = {}
    this.audioData = {}
    this.isPlaying = false
    this.playWindowEndMs = null
    this.loopEnabled = false
    this.draggingProgress = false
    this.seekOnNextPlay = true
    this.jumpToken = 0

    this.versePaginaiton = {};
    this.segmentPaginaiton = {};

    this.prevAyahButton = document.getElementById("previous-ayah");
    this.nextAyahButton = document.getElementById("next-ayah");
    this.ayahSelect = document.getElementById("ayah-select");

    this.playButton = this.element.querySelector('#play-button');
    this.progressBar = this.element.querySelector('#progress-bar');
    this.progress = this.element.querySelector('#progress');
    this.progressHandle = this.element.querySelector('#progress-handle');
    this.currentTime = this.element.querySelector('#current-time');
    this.totalTime = this.element.querySelector('#total-duration');
    this.loopButton = this.element.querySelector('#loop-button');
    this.currentVerseKeyLabel = this.element.querySelector('#current-verse-key');

    this.loadingIndicator = this.createLoadingIndicator();
    this.ayahContainer = this.element.querySelector("#current-ayah");
    this.highlightBg = this.ayahContainer.querySelector("#word-highlight");

    this.bindEvents();

    await this.loadVerses(verseKey).then(() => {
      this.renderAyah(verseKey);
    });
  }

  disconnect() {
    if (this.playerId)
      cancelAnimationFrame(this.playerId);

    if (this.player) {
      this.player.unload();
      this.player = null;
    }
  }

  createLoadingIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'absolute inset-0 flex items-center justify-center bg-white/80 z-10 hidden';
    indicator.innerHTML = `
      <svg class="animate-spin h-5 w-5 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" width="24" height="24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `;
    this.element.appendChild(indicator);
    return indicator;
  }

  showLoading() {
    this.loading = true;
    this.loadingIndicator.classList.remove('hidden');
  }

  hideLoading() {
    this.loading = false;
    this.loadingIndicator.classList.add('hidden');
  }

  bindEvents() {
    this.playButton.addEventListener('click', this.togglePlay.bind(this));
    this.loopButton.addEventListener('click', this.toggleLoop.bind(this));
    this.progressBar.addEventListener('pointerdown', this.startSeek.bind(this));

    this.prevAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.prevAyahButton.href);
      const key = url.searchParams.get("ayah");
      if (key) {
        this.jumpToVerseAndResume(key);
      }
    });

    this.nextAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.nextAyahButton.href);
      const key = url.searchParams.get("ayah");

      if (key) {
        this.jumpToVerseAndResume(key);
      }
    });

    $(this.ayahSelect).on("select2:select", (e) => {
      const key = e.params.data.id;
      if (key) {
        this.jumpToVerseAndResume(key);
      }
    });
  }

  startSeek(event) {
    if (!this.player) {
      this.initializePlayer();
    }

    this.draggingProgress = true;
    this.seek(event);

    const onMove = (moveEvent) => {
      if (this.draggingProgress) {
        this.seek(moveEvent);
      }
    };

    const onUp = () => {
      this.draggingProgress = false;
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };

    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
  }

  async seek(event) {
    event.preventDefault();

    if (!this.player || !this.player.duration()) {
      return;
    }

    const rect = this.progressBar.getBoundingClientRect();
    const ratio = Math.min(Math.max((event.clientX - rect.left) / rect.width, 0), 1);
    const time = ratio * this.player.duration();

    this.player.seek(time);
    this.currentTime.textContent = this.formatTime(time);
    this.updateProgressPosition(ratio * 100);
    await this.updateVerse(time * 1000);
    this.updateHighlighting(time * 1000);
  }

  async loadVerses(verseKey) {
    if (this.verses[verseKey]) {
      return;
    }

    this.showLoading();

    const chapter = QuranUtils.getSurahNumberFromVerseKey(verseKey);
    const from = QuranUtils.getAyahNumberFromVerseKey(verseKey);

    try {
      const response = await fetch(`/api/v1/chapters/${chapter}/verses?words=true&from=${from}&per_page=5`);
      const data = await response.json();

      for (const verse of data.verses) {
        this.verses[verse.verse_key] = verse;
      }

      await this.loadSegments(verseKey)
    } catch (err) {
      console.error("Failed to load verses", verseKey, err);
    } finally {
      this.playButton.removeAttribute("disabled");
      this.hideLoading();
    }
  }

  onplay() {
    this.isPlaying = true;
    cancelAnimationFrame(this.playerId);
    this.playerId = requestAnimationFrame(() => this.updateProgress());
    const icon = this.playButton.querySelector("i");
    icon.classList.add("fa-pause");
    icon.classList.remove("fa-play");
  }

  async updateProgress() {
    if (!this.player) {
      return;
    }

    const time = this.player.seek();
    const timeMs = time * 1000;

    if (this.loopEnabled && this.shouldRestartLoop(timeMs)) {
      this.restartCurrentVerse();
      this.playerId = requestAnimationFrame(() => this.updateProgress());
      return;
    }

    if (this.playWindowEndMs !== null && timeMs >= this.playWindowEndMs) {
      this.playWindowEndMs = null;
      this.playNextAyah();
      return;
    }

    this.currentTime.textContent = this.formatTime(time);

    const progressPercent = (time / this.player.duration()) * 100;
    this.updateProgressPosition(progressPercent);

    await this.updateVerse(timeMs);

    if (!this.isPlaying) {
      return;
    }

    this.updateHighlighting(timeMs);

    this.playerId = requestAnimationFrame(() => this.updateProgress());
  }

  updateProgressPosition(percent) {
    const progress = Math.min(Math.max(percent, 0), 100);

    this.progress.style.width = `${progress}%`;
    this.progressHandle.style.left = `${progress}%`;
  }

  updateHighlighting(time) {
    const segment = this.findSegmentAtTime(time);
    if (!segment) {
      this.highlightBg.classList.add("hidden");
      return;
    }

    const location = `${this.currentVerseKey}:${segment[0]}`;
    const word = this.ayahContainer.querySelector(`[data-location="${location}"]`);
    if (!word) {
      this.highlightBg.classList.add("hidden");
      return;
    }

    const containerRect = this.ayahContainer.getBoundingClientRect();
    const wordRect = word.getBoundingClientRect();

    const top = wordRect.top - containerRect.top + this.ayahContainer.scrollTop;
    const left = wordRect.left - containerRect.left + this.ayahContainer.scrollLeft;

    this.highlightBg.classList.remove("hidden");
    this.highlightBg.style.top = `${top}px`;
    this.highlightBg.style.left = `${left}px`;
    this.highlightBg.style.width = `${wordRect.width}px`;
    this.highlightBg.style.height = `${wordRect.height}px`;
  }

  onpause() {
    this.isPlaying = false;
    cancelAnimationFrame(this.playerId);

    const icon = this.playButton.querySelector("i");
    icon.classList.add("fa-play");
    icon.classList.remove("fa-pause");
  }

  onend() {
    cancelAnimationFrame(this.playerId);

    if (this.loopEnabled) {
      this.restartCurrentVerse();
    } else {
      this.playNextAyah();
    }
  }

  onload() {
    this.updateTotalDuration();
  }

  updateTotalDuration() {
    const duration = this.player.duration();
    this.totalTime.textContent = this.formatTime(duration);
  }

  onloaderror() {
    //TODO: Handle error loading audio
  }

  renderAyah(verseKey) {
    const verse = this.verses[verseKey];
    if (!verse) {
      console.error("Verse not found:", verseKey);
      return;
    }

    const container = this.element.querySelector("#current-ayah #words");

    container.innerHTML = "";

    verse.words.forEach(word => {
      const div = document.createElement("span");
      div.textContent = word.text;
      div.dataset.location = word.location;
      div.className = "relative z-10 rounded-md px-1";
      container.appendChild(div);
    });
    this.highlightBg.classList.add("hidden");
    this.currentVerseKeyLabel.textContent = verseKey;
  }


  async jumpToVerse(verseKey) {
    const jumpToken = ++this.jumpToken;
    const parts = verseKey.split(":");
    this.currentChapter = parseInt(parts[0], 10);
    this.currentVerseNumber = parseInt(parts[1], 10);
    this.currentVerseKey = verseKey;

    const url = new URL(window.location);
    url.searchParams.set("ayah", verseKey);
    history.pushState({}, "", url);

    const verseId = QuranUtils.getAyahIdFromKey(verseKey);
    this.updateAyahSelect(verseKey);

    const prevVerseNumber = verseId - 1;
    const nextVerseNumber = verseId + 1;

    if (prevVerseNumber >= 1) {
      this.prevAyahButton.classList.remove("hidden");
      this.prevAyahButton.href = this.buildVerseUrl(prevVerseNumber);
    } else {
      this.prevAyahButton.classList.add("hidden");
    }

    if (nextVerseNumber <= 6236) {
      this.nextAyahButton.classList.remove("hidden");
      this.nextAyahButton.href = this.buildVerseUrl(nextVerseNumber);
    } else {
      this.nextAyahButton.classList.add("hidden");
    }

    await this.loadVerses(verseKey)

    if (jumpToken === this.jumpToken) {
      this.renderAyah(verseKey);
    }
  }

  async jumpToVerseAndResume(verseKey) {
    const shouldResume = this.isPlaying;

    if (shouldResume && this.player) {
      this.player.pause();
    }

    await this.jumpToVerse(verseKey);

    if (shouldResume) {
      this.playAyah(verseKey);
      this.seekOnNextPlay = false;
      this.player.play();
    } else {
      this.seekOnNextPlay = true;
    }
  }

  buildVerseUrl(verseId) {
    const key = QuranUtils.getAyahKeyFromId(verseId);
    const url = new URL(window.location);

    url.searchParams.set("ayah", key);
    return url.toString();
  }

  updateAyahSelect(verseKey) {
    if (!this.ayahSelect) {
      return;
    }

    if (!this.ayahSelect.querySelector(`option[value="${verseKey}"]`)) {
      this.ayahSelect.append(new Option(verseKey, verseKey, true, true));
    }

    $(this.ayahSelect).val(verseKey).trigger('change');
  }

  nextVerseKey() {
    const verseId = QuranUtils.getAyahIdFromKey(this.currentVerseKey);

    if (!verseId || verseId >= 6236) {
      return null;
    }

    return QuranUtils.getAyahKeyFromId(verseId + 1);
  }

  async playNextAyah() {
    const key = this.nextVerseKey();

    if (!key) {
      this.isPlaying = false;
      this.player.seek(0);
      this.updateProgressPosition(0);
      return;
    }

    await this.jumpToVerse(key);
    this.playAyah(key);
    this.seekOnNextPlay = false;
    this.player.play();
  }

  toggleLoop() {
    this.loopEnabled = !this.loopEnabled;
    this.loopButton.setAttribute('aria-pressed', this.loopEnabled.toString());
    this.loopButton.classList.toggle('bg-primary-100', this.loopEnabled);
    this.loopButton.classList.toggle('text-primary-700', this.loopEnabled);
    this.loopButton.classList.toggle('bg-slate-100', !this.loopEnabled);
    this.loopButton.classList.toggle('text-slate-500', !this.loopEnabled);
  }

  shouldRestartLoop(timeMs) {
    const endMs = this.currentVerseEndMs();

    return endMs !== null && timeMs >= endMs;
  }

  restartCurrentVerse() {
    this.player.seek(this.currentVerseStartMs() / 1000);

    if (!this.player.playing()) {
      this.player.play();
    }
  }

  currentVerseStartMs() {
    return this.segmentsData[this.currentVerseKey]?.time_from || 0;
  }

  currentVerseEndMs() {
    return this.segmentsData[this.currentVerseKey]?.time_to || (this.player.duration() * 1000);
  }

  isPlayerReadyForVerse(verseKey) {
    return Boolean(this.player && verseKey);
  }

  togglePlay() {
    if (!this.player) {
      this.initializePlayer();
    }

    if (this.isPlaying) {
      this.player.pause();
    } else {
      if (this.seekOnNextPlay || !this.isPlayerReadyForVerse(this.currentVerseKey)) {
        this.playAyah(this.currentVerseKey);
        this.seekOnNextPlay = false;
      }

      this.player.play();
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? "0" + s : s}`;
  }
}

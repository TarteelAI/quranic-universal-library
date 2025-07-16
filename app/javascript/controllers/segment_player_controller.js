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
    this.segmnetsData = {}
    this.audioData = {}
    this.isPlaying = false

    this.versePaginaiton = {};
    this.segmentPaginaiton = {};

    this.prevAyahButton = document.getElementById("previous-ayah");
    this.nextAyahButton = document.getElementById("next-ayah");
    this.ayahSelect = document.getElementById("ayah-select");

    this.playButton = this.element.querySelector('#play-button');
    this.progressBar = this.element.querySelector('#progress-bar');
    this.currentTime = this.element.querySelector('#current-time');
    this.totalTime = this.element.querySelector('#total-duration');

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
    indicator.className = 'tw-absolute tw-inset-0 tw-flex tw-items-center tw-justify-center tw-bg-white/80 tw-z-10 tw-hidden';
    indicator.innerHTML = `
      <svg class="animate-spin h-5 w-5 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" width="24" height="24">
        <circle class="tw-opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="tw-opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `;
    this.element.appendChild(indicator);
    return indicator;
  }

  showLoading() {
    this.loading = true;
    this.loadingIndicator.classList.remove('tw-hidden');
  }

  hideLoading() {
    this.loading = false;
    this.loadingIndicator.classList.add('tw-hidden');
  }

  bindEvents() {
    this.playButton.addEventListener('click', this.togglePlay.bind(this));
    this.progressBar.addEventListener('click', this.seek.bind(this));

    this.prevAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.prevAyahButton.href);
      const key = url.searchParams.get("ayah");
      if (key) {
        this.jumpToVerse(key).then(() => {
         if(this.isPlaying){
            this.playAyah(key);
         }
        })
      }
    });

    this.nextAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.nextAyahButton.href);
      const key = url.searchParams.get("ayah");

      if (key) {
        this.jumpToVerse(key).then(() => {
          if(this.isPlaying){
            this.playAyah(key);
          }
        })
      }
    });

    $(this.ayahSelect).on("select2:select", (e) => {
      const key = e.params.data.id;
      if (key) {
        this.jumpToVerse(key).then(() => {
          if(this.isPlaying){
            this.playAyah(key);
          }
        })
      }
    });
  }

  seek(event) {

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
    this.playerId = requestAnimationFrame(() => this.updateProgress());
    const icon = this.playButton.querySelector("i");
    icon.classList.add("fa-pause");
    icon.classList.remove("fa-play");
  }

  updateProgress() {
    const time = this.player.seek();
    this.currentTime.textContent = this.formatTime(time);

    const progressPercent = (time / this.player.duration()) * 100;
    this.progressBar.style.width = `${progressPercent}%`;

    this.updateVerse(time * 1000);
    this.updateHighlighting(time * 1000);

    this.playerId = requestAnimationFrame(() => this.updateProgress());
  }

  updateHighlighting(time) {
    const segment = this.findSegmentAtTime(time);
    if (!segment) return;

    const location = `${this.currentVerseKey}:${segment[0]}`;
    const word = this.ayahContainer.querySelector(`[data-location="${location}"]`);
    if (!word) return;

    const containerRect = this.ayahContainer.getBoundingClientRect();
    const wordRect = word.getBoundingClientRect();

    const top = wordRect.top - containerRect.top + this.ayahContainer.scrollTop;
    const left = wordRect.left - containerRect.left + this.ayahContainer.scrollLeft;

    this.highlightBg.style.display = 'block';
    this.highlightBg.style.top = `${top}px`;
    this.highlightBg.style.left = `${left}px`;
    this.highlightBg.style.width = `${wordRect.width}px`;
    this.highlightBg.style.height = `${wordRect.height}px`;
  }

  onpause() {
    this.isPlaying = false;
    cancelAnimationFrame(this.playerId);

    const icon = this.playButton.querySelector("i");
    icon.classList.add("fa-pause");
    icon.classList.remove("fa-play");
  }

  onend() {
    this.isPlaying = false;
    this.player.seek(0);
  }

  onload() {
    const duraton = this.player.duration();
    this.totalTime.textContent = this.formatTime(duraton);
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
      container.appendChild(div);
    });
    this.highlightBg.style.display = "none";
  }


  async jumpToVerse(verseKey) {
    const parts = verseKey.split(":");
    this.currentChapter = parts[0];
    this.currentVerseNumber = parts[1];
    this.currentVerseKey = verseKey;

    const url = new URL(window.location);
    url.searchParams.set("ayah", verseKey);
    history.pushState({}, "", url);

    const verseId = QuranUtils.getAyahIdFromKey(verseKey);
    document.querySelector('#select2-ayah-select-container').textContent = verseKey

    const prevVerseNumber = verseId - 1;
    const nextVerseNumber = verseId + 1;

    if (prevVerseNumber >= 1) {
      this.prevAyahButton.classList.remove("tw-hidden");
      this.prevAyahButton.href = this.buildVerseUrl(prevVerseNumber);
    } else {
      this.prevAyahButton.classList.add("tw-hidden");
    }

    if (nextVerseNumber <= 6236) {
      this.nextAyahButton.classList.remove("tw-hidden");
      this.nextAyahButton.href = this.buildVerseUrl(nextVerseNumber);
    } else {
      this.nextAyahButton.classList.add("tw-hidden");
    }

    await this.loadVerses(verseKey).then(() => {
      this.renderAyah(verseKey);
    })
  }

  buildVerseUrl(verseId) {
    const key = QuranUtils.getAyahKeyFromId(verseId);

    return `/resources/recitation/${this.resource}?ayah=${key}`;
  }

  togglePlay() {
    if (!this.player) {
      this.initializePlayer();
    }

    if (this.isPlaying) {
      this.player.pause();
    } else {
      this.playAyah(this.currentVerseKey);
      this.player.play();
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? "0" + s : s}`;
  }
}

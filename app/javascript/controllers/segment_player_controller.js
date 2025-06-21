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

    this.versePaginaiton = {};
    this.segmentPaginaiton = {};

    this.prevAyahButton = document.getElementById("previous-ayah");
    this.nextAyahButton = document.getElementById("next-ayah");

    await this.loadVerses(verseKey).then(() => {
      this.renderCurrentAyah();
    });

    this.registerVerseJumpListeners();
  }

  registerVerseJumpListeners() {
    const select = document.getElementById("ayah-select");

    this.prevAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.prevAyahButton.href);
      const key = url.searchParams.get("ayah");
      if (key) this.jumpToVerse(key);
    });

    this.nextAyahButton.addEventListener("click", (e) => {
      e.preventDefault();
      const url = new URL(this.nextAyahButton.href);
      const key = url.searchParams.get("ayah");
      if (key) this.jumpToVerse(key);
    });

    $(select).on("select2:select", (e) => {
      const verseKey = e.params.data.id;
      if (verseKey) this.jumpToVerse(verseKey);
    });
  }

  async loadVerses(verseKey) {
    const chapter = QuranUtils.getSurahNumberFromVerseKey(verseKey);
    const from = QuranUtils.getAyahNumberFromVerseKey(verseKey);

    try {
      const response = await fetch(`/api/v1/chapters/${chapter}/verses?words=true&from=${from}&per_page=5`);
      const data = await response.json();

      for (const verse of data.verses) {
        this.verses[verse.verse_key] = verse;
      }
    } catch (err) {
      console.error("Failed to load verses", verseKey, err);
    }
  }

  renderCurrentAyah() {
    if (!this.verses[this.currentVerseKey]) return;

    const verse = this.verses[this.currentVerseKey];
    const container = this.element.querySelector("#current-ayah");

    container.innerHTML = "";

    verse.words.forEach(word => {
      const div = document.createElement("span");
      div.textContent = word.text;
      div.dataset.location = word.location;
      container.appendChild(div);
    });
  }

  jumpToVerse(verseKey) {
    this.currentVerseNumber = verseNumber;

    const verse = this.verses[verseKey];

    if (!verse) {
      return;
    }
    this.currentVerseKey = verseKey;


    const prevVerseNumber = verseNumber - 1;
    const nextVerseNumber = verseNumber + 1;

    if (prevVerseNumber >= 1) {
      prevLink.classList.remove("tw-hidden");
      prevLink.href = this.buildVerseUrl(prevVerseNumber);
    } else {
      prevLink.classList.add("tw-hidden");
    }

    if (nextVerseNumber <= this.totalVerses) {
      nextLink.classList.remove("tw-hidden");
      nextLink.href = this.buildVerseUrl(nextVerseNumber);
    } else {
      nextLink.classList.add("tw-hidden");
    }

    this.renderCurrentAyah();
  }

  buildVerseUrl(verseNumber) {
    return `/resources/recitation/${this.resource}?ayah=${this.chapter}:${verseNumber}`;
  }

  initializePlayer() {
  }

  trackProgress() {
    const update = () => {
      const time = this.audio.seek();

      this.currentTimeTarget.textContent = this.formatTime(time);
      const percentage = (time / this.audio.duration()) * 100;
      this.progressTarget.style.width = `${percentage}%`;

      this.highlightWord(time);

      if (this.audio.playing()) {
        requestAnimationFrame(update);
      }
    };
    requestAnimationFrame(update);
  }

  highlightWord(currentTime) {

  }

  togglePlay() {
    if (!this.audio) return;

    if (this.audio.playing()) {
      this.audio.pause();
    } else {
      this.audio.play();
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? "0" + s : s}`;
  }
}

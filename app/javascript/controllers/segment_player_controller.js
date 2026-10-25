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
    this.draggingProgress = false
    this.seekOnNextPlay = true
    this.jumpToken = 0
    this.pendingSeekRatio = null

    // Range repeat: play `range.from`..`range.to`, each ayah `ayahRepeat`
    // times, the whole range `rangeRepeat` times (Infinity to loop forever).
    this.range = null
    this.ayahRepeatCounter = 0
    this.rangeRepeatCounter = 0
    this.handlingRangeBoundary = false
    this.rangeFinished = false
    this.rangeSeek = null
    this.progressLoopToken = 0
    this.progressFallbackId = null
    this.progressStepping = false

    this.versePaginaiton = {};
    this.segmentPaginaiton = {};

    this.prevAyahButton = document.getElementById("previous-ayah");
    this.nextAyahButton = document.getElementById("next-ayah");
    this.ayahSelect = document.getElementById("ayah-select");

    this.playButton = this.element.querySelector('#play-button');
    this.progressBar = this.element.querySelector('#progress-bar');
    this.progressInput = this.element.querySelector('#progress-input');
    this.progress = this.element.querySelector('#progress');
    this.progressHandle = this.element.querySelector('#progress-handle');
    this.currentTime = this.element.querySelector('#current-time');
    this.totalTime = this.element.querySelector('#total-duration');
    this.currentVerseKeyLabel = this.element.querySelector('#current-verse-key');

    this.rangeButton = this.element.querySelector('#range-repeat-button');
    this.rangePanel = this.element.querySelector('#range-repeat-panel');
    this.rangeFromSelect = this.element.querySelector('#range-from');
    this.rangeToSelect = this.element.querySelector('#range-to');
    this.rangeAyahRepeatInput = this.element.querySelector('#range-ayah-repeat');
    this.rangeRepeatInput = this.element.querySelector('#range-repeat-count');
    this.rangeForeverInput = this.element.querySelector('#range-repeat-forever');
    this.rangeAyahRepeatLabel = this.element.querySelector('#range-ayah-repeat-label');
    this.rangeRepeatField = this.element.querySelector('#range-repeat-count-field');
    this.rangeForeverLabel = this.element.querySelector('#range-forever-label');
    this.rangeApplyLabel = this.element.querySelector('#range-repeat-apply-label');
    this.rangeError = this.element.querySelector('#range-repeat-error');
    this.rangeStatus = this.element.querySelector('#range-repeat-status');

    this.loadingIndicator = this.createLoadingIndicator();
    this.ayahContainer = this.element.querySelector("#current-ayah");
    this.highlightBg = this.ayahContainer.querySelector("#word-highlight");

    this.bindEvents();

    await this.loadVerses(verseKey).then(() => {
      this.renderAyah(verseKey);
    });

    // Line the player up with the ayah in the URL so the progress bar and
    // clock match the ayah on screen before anything is played.
    this.cueCurrentVerse();
  }

  cueCurrentVerse() {
    if (!this.player) {
      this.initializePlayer();
    }
    if (!this.player) return;

    this.playAyah(this.currentVerseKey);
    this.seekOnNextPlay = false;
    this.refreshProgressFromPlayer();
  }

  disconnect() {
    this.stopProgressLoop();

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
    this.bindRangeEvents();

    this.progressInput.addEventListener('pointerdown', () => { this.draggingProgress = true; });
    this.progressInput.addEventListener('pointerup', () => { this.draggingProgress = false; });
    this.progressInput.addEventListener('keydown', () => { this.draggingProgress = true; });
    this.progressInput.addEventListener('keyup', () => { this.draggingProgress = false; });
    this.progressInput.addEventListener('input', (event) => {
      this.seekToRatio(Number(event.target.value) / Number(event.target.max));
    });

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

  async seekToRatio(ratio) {
    const clamped = Math.min(Math.max(ratio, 0), 1);

    if (!this.player) {
      this.initializePlayer();
    }

    // Seeking before the audio has reported a duration would land at 0, so
    // remember where the user aimed and apply it once the file is ready.
    const duration = this.player && this.player.duration();
    if (!duration) {
      this.pendingSeekRatio = clamped;
      this.updateProgressPosition(clamped * 100);
      return;
    }

    const time = clamped * duration;

    this.player.seek(time);
    this.playWindowEndMs = null;
    this.seekOnNextPlay = false;
    this.currentTime.textContent = this.formatTime(time);
    this.updateProgressPosition(clamped * 100);
    await this.updateVerse(time * 1000);
    this.updateHighlighting(time * 1000);
  }

  refreshProgressFromPlayer() {
    const duration = this.player && this.player.duration();
    if (!duration) return;

    const time = this.player.seek() || 0;
    this.currentTime.textContent = this.formatTime(time);
    this.updateProgressPosition((time / duration) * 100);
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

  // The progress loop drives the clock, the progress bar and the highlight, so
  // it must survive Howler's event ordering. Seeking to another ayah pauses and
  // replays the sound, and the `pause` can be delivered *after* the `play` that
  // followed it; a loop torn down by that stale event would leave the highlight
  // stuck on one ayah while the recitation carried on. So the loop owns its own
  // lifetime: a token invalidates older loops, and it ends only once the player
  // has genuinely stayed stopped rather than on a single idle frame.
  startProgressLoop() {
    const token = ++this.progressLoopToken;
    let idleFrames = 0;
    let lastPosition = null;
    let lastFrameAt = performance.now();

    const tick = async () => {
      if (token !== this.progressLoopToken) return;

      lastFrameAt = performance.now();
      await this.step();
      if (token !== this.progressLoopToken) return;

      // Resuming a streamed surah file after a seek can leave the player
      // reporting "not playing" for the better part of a second, so idleness
      // alone must not end the loop — only a player that is both stopped and
      // not advancing, for long enough that no buffering explains it.
      const position = this.player ? this.player.seek() : 0;
      const stalled = this.player && !this.player.playing() && position === lastPosition;
      lastPosition = position;
      idleFrames = stalled ? idleFrames + 1 : 0;
      if (idleFrames > 600) return;

      this.playerId = requestAnimationFrame(tick);
    };

    cancelAnimationFrame(this.playerId);
    this.playerId = requestAnimationFrame(tick);

    // A hidden tab stops delivering animation frames, and a repeat with no one
    // watching the boundaries runs straight past its last ayah. This timer
    // takes over whenever frames dry up; browsers clamp it to about a second
    // in the background, which still stops the range close enough to its end.
    clearInterval(this.progressFallbackId);
    this.progressFallbackId = setInterval(() => {
      if (token !== this.progressLoopToken) {
        clearInterval(this.progressFallbackId);
        return;
      }
      if (performance.now() - lastFrameAt < 400) return;
      this.step();
    }, 250);
  }

  stopProgressLoop() {
    this.progressLoopToken += 1;
    cancelAnimationFrame(this.playerId);
    clearInterval(this.progressFallbackId);
  }

  // One pass of the progress handling, never two at once: the animation frame
  // and the fallback timer both drive it.
  async step() {
    if (this.progressStepping) return;

    this.progressStepping = true;
    try {
      await this.updateProgress();
    } finally {
      this.progressStepping = false;
    }
  }

  onplay() {
    this.isPlaying = true;
    this.startProgressLoop();
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

    if (this.range && this.handleRangeProgress(timeMs)) {
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
  }

  updateProgressPosition(percent) {
    const progress = Math.min(Math.max(percent, 0), 100);

    this.progress.style.width = `${progress}%`;
    this.progressHandle.style.left = `${progress}%`;

    if (this.progressInput && !this.draggingProgress) {
      this.progressInput.value = Math.round((progress / 100) * Number(this.progressInput.max));
    }
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
    // Pausing and immediately replaying (every seek to another ayah does that)
    // can deliver Howler's `pause` *after* the `play` that followed it. Tearing
    // the progress loop down then would leave the highlight frozen on one ayah
    // while the recitation carries on, so trust the player's own state.
    if (this.player && this.player.playing()) {
      return;
    }

    this.isPlaying = false;

    const icon = this.playButton.querySelector("i");
    icon.classList.add("fa-play");
    icon.classList.remove("fa-pause");
  }

  onend() {
    this.stopProgressLoop();

    if (this.range && this.takeRangeAction()) {
      return;
    }

    this.playNextAyah();
  }

  onload() {
    this.updateTotalDuration();

    if (this.pendingSeekRatio !== null) {
      const ratio = this.pendingSeekRatio;
      this.pendingSeekRatio = null;
      this.seekToRatio(ratio);
    } else if (!this.isPlaying) {
      this.refreshProgressFromPlayer();
    }
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

  // Picking an ayah from the select or the prev/next buttons is an explicit
  // request for that ayah: move the audio there and start playing it.
  async jumpToVerseAndResume(verseKey) {
    if (this.player) {
      this.player.pause();
    }

    await this.jumpToVerse(verseKey);

    this.playAyah(verseKey);
    this.seekOnNextPlay = false;

    if (this.player) {
      this.player.play();
      this.startProgressLoop();
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
    this.startProgressLoop();
  }

  bindRangeEvents() {
    if (!this.rangeButton) return;

    this.rangeButton.addEventListener('click', () => this.toggleRangePanel());
    this.element.querySelector('#range-repeat-close')
      .addEventListener('click', () => this.closeRangePanel());
    this.element.querySelector('#range-repeat-apply')
      .addEventListener('click', () => this.applyRange());
    this.element.querySelector('#range-repeat-clear')
      .addEventListener('click', () => this.clearRange());

    this.rangeForeverInput.addEventListener('change', () => this.syncRangeFields());
    this.rangeFromSelect.addEventListener('change', () => this.syncRangeFields());
    this.rangeToSelect.addEventListener('change', () => this.syncRangeFields());
  }

  // One control covers both cases: picking the same ayah for both ends is how
  // the user asks for a plain single-ayah repeat, so the fields that only make
  // sense for a real range step out of the way.
  isSingleAyahSelection() {
    return this.rangeFromSelect.value === this.rangeToSelect.value;
  }

  syncRangeFields() {
    const single = this.isSingleAyahSelection();

    this.rangeRepeatField.classList.toggle('hidden', single);
    this.rangeAyahRepeatLabel.textContent = single ? 'Repeat count' : 'Repeat each ayah';
    this.rangeForeverLabel.textContent = single ? 'Repeat forever' : 'Loop the range forever';
    this.rangeApplyLabel.textContent = single ? 'Repeat ayah' : 'Play range';

    this.rangeAyahRepeatInput.disabled = single && this.rangeForeverInput.checked;
    this.rangeRepeatInput.disabled = this.rangeForeverInput.checked;
  }

  toggleRangePanel() {
    if (this.rangePanel.classList.contains('hidden')) {
      this.populateRangeSelects();
      this.rangePanel.classList.remove('hidden');
      this.rangeButton.setAttribute('aria-expanded', 'true');
    } else {
      this.closeRangePanel();
    }
  }

  closeRangePanel() {
    this.rangePanel.classList.add('hidden');
    this.rangeButton.setAttribute('aria-expanded', 'false');
  }

  // The selects only ever offer ayahs of the surah on screen — the surah file
  // and the loaded segments both stop at its boundary.
  populateRangeSelects() {
    const ayahCount = QuranUtils.getSurahAyahCount(this.currentChapter);
    const options = Array.from({length: ayahCount}, (_, i) => {
      const key = `${this.currentChapter}:${i + 1}`;
      return `<option value="${key}">${key}</option>`;
    }).join('');

    const from = this.range?.from || this.currentVerseKey;
    const to = this.range?.to || this.currentVerseKey;

    this.rangeFromSelect.innerHTML = options;
    this.rangeToSelect.innerHTML = options;
    this.rangeFromSelect.value = from;
    this.rangeToSelect.value = to;

    this.rangeAyahRepeatInput.value = this.range?.ayahRepeat || 1;
    this.rangeForeverInput.checked = this.range?.rangeRepeat === Infinity;
    if (this.range && this.range.rangeRepeat !== Infinity) {
      this.rangeRepeatInput.value = this.range.rangeRepeat;
    }
    this.syncRangeFields();
    this.hideRangeError();
  }

  showRangeError(message) {
    this.rangeError.textContent = message;
    this.rangeError.classList.remove('hidden');
  }

  hideRangeError() {
    this.rangeError.classList.add('hidden');
  }

  async applyRange() {
    const from = this.rangeFromSelect.value;
    const to = this.rangeToSelect.value;

    if (QuranUtils.getAyahIdFromKey(from) > QuranUtils.getAyahIdFromKey(to)) {
      this.showRangeError('The first ayah must come before the last ayah.');
      return;
    }

    const clamp = (input) => Math.min(Math.max(parseInt(input.value, 10) || 1, 1), 99);

    const forever = this.rangeForeverInput.checked;
    const single = this.isSingleAyahSelection();

    this.range = {
      from,
      to,
      // A forever single-ayah repeat is just a one-ayah range on an endless
      // loop, so the same counters drive both cases.
      ayahRepeat: single && forever ? 1 : clamp(this.rangeAyahRepeatInput),
      rangeRepeat: forever ? Infinity : (single ? 1 : clamp(this.rangeRepeatInput)),
    };
    this.ayahRepeatCounter = 0;
    this.rangeRepeatCounter = 0;
    this.rangeFinished = false;
    // Until the jump below lands, the player is still somewhere else, and
    // `updateVerse` would drag the range onto whatever ayah that is.
    this.awaitRangeSeek(this.segmentsData[from]?.time_from || 0);

    this.hideRangeError();
    this.closeRangePanel();
    this.renderRangeState();

    await this.jumpToVerseAndResume(from);
  }

  clearRange() {
    this.range = null;
    this.ayahRepeatCounter = 0;
    this.rangeRepeatCounter = 0;
    this.rangeFinished = false;
    this.rangeSeek = null;
    this.closeRangePanel();
    this.renderRangeState();
  }

  renderRangeState() {
    const active = Boolean(this.range);

    this.rangeButton.setAttribute('aria-pressed', active.toString());
    this.rangeButton.classList.toggle('bg-emerald-100', active);
    this.rangeButton.classList.toggle('text-emerald-700', active);
    this.rangeButton.classList.toggle('bg-slate-100', !active);
    this.rangeButton.classList.toggle('text-slate-500', !active);

    this.rangeStatus.classList.toggle('hidden', !active);
    if (!active) return;

    if (this.rangeFinished) {
      this.rangeStatus.textContent = this.range.from === this.range.to
        ? `Finished repeating ${this.range.from}`
        : `Finished repeating ${this.range.from} – ${this.range.to}`;
      return;
    }

    const {from, to, ayahRepeat, rangeRepeat} = this.range;
    const forever = rangeRepeat === Infinity;

    if (from === to) {
      const count = forever ? '∞' : ayahRepeat;
      this.rangeStatus.textContent = `Repeating ${from} (play ${this.ayahRepeatCounter + 1} of ${count})`;
      return;
    }

    const pass = forever
      ? `pass ${this.rangeRepeatCounter + 1} of ∞`
      : `pass ${Math.min(this.rangeRepeatCounter + 1, rangeRepeat)} of ${rangeRepeat}`;
    const each = ayahRepeat > 1 ? `, each ayah ×${ayahRepeat}` : '';

    this.rangeStatus.textContent = `Repeating ${from} – ${to} (${pass}${each})`;
  }

  // Decides what to do now that the audio for `currentVerseKey` has finished.
  nextRangeAction() {
    const {to, ayahRepeat, rangeRepeat} = this.range;

    if (this.ayahRepeatCounter < ayahRepeat - 1) {
      this.ayahRepeatCounter += 1;
      return 'repeat-ayah';
    }

    this.ayahRepeatCounter = 0;

    if (this.currentVerseKey !== to) {
      return 'next-ayah';
    }

    if (rangeRepeat === Infinity || this.rangeRepeatCounter < rangeRepeat - 1) {
      this.rangeRepeatCounter += 1;
      return 'repeat-range';
    }

    return 'stop';
  }

  // A media element keeps reporting its pre-seek position for a while after a
  // seek, and over a streamed two-hour surah file that can be several hundred
  // milliseconds. Treating one of those stale readings as "this ayah ended"
  // would count another repeat and step the ayah forward while the audio is
  // still where it was, leaving the highlight one ayah ahead of the recitation
  // for the rest of the range. So after every range seek we ignore positions
  // until the player reports one that actually lands in the window we asked
  // for, with a deadline so a seek that never lands cannot wedge the player.
  awaitRangeSeek(targetMs) {
    this.rangeSeek = {targetMs, deadline: performance.now() + 5000};
  }

  rangeSeekSettled(timeMs) {
    if (!this.rangeSeek) return true;

    const {targetMs, deadline} = this.rangeSeek;
    const landed = timeMs >= targetMs - 250 && timeMs <= targetMs + 2000;

    if (landed || performance.now() > deadline) {
      this.rangeSeek = null;
      return true;
    }

    return false;
  }

  // Returns true when the range took over this frame and the caller should not
  // run its normal progress handling.
  handleRangeProgress(timeMs) {
    if (!this.range || this.handlingRangeBoundary) return false;

    // Suppress everything, highlighting included, until the seek has landed:
    // the position we are being handed belongs to the previous ayah.
    if (!this.rangeSeekSettled(timeMs)) return true;

    const startMs = this.currentVerseStartMs();
    const endMs = this.currentVerseEndMs();

    if (timeMs < startMs) return false;
    if (endMs === null || timeMs < endMs) return false;

    return this.takeRangeAction({advanceWithinFile: true});
  }

  // Applies the decision for the ayah that just finished. Returns true when it
  // moved the player itself, false when the caller should carry on as usual.
  takeRangeAction({advanceWithinFile = false} = {}) {
    // `updateProgress` and `onend` can both see the same ayah finish; without
    // this the range would be counted down twice for one play.
    if (this.rangeSeek) return true;

    const action = this.nextRangeAction();

    if (action === 'next-ayah') {
      // Nothing to seek: the surah file flows into the next ayah on its own.
      // The label still has to move here rather than wait for `updateVerse`,
      // because the silence between two ayahs matches no segment at all — the
      // key would stay put across that gap and the next frame would read the
      // boundary a second time and repeat the ayah instead of moving on.
      if (!advanceWithinFile) return false;

      const nextKey = this.nextVerseKey();
      if (!nextKey) return false;

      this.jumpToVerse(nextKey);
      return true;
    }

    this.handlingRangeBoundary = true;

    if (action === 'repeat-ayah') {
      this.awaitRangeSeek(this.currentVerseStartMs());
      this.restartCurrentVerse();
      this.renderRangeState();
      this.handlingRangeBoundary = false;
      return true;
    }

    if (action === 'repeat-range') {
      this.awaitRangeSeek(this.segmentsData[this.range.from]?.time_from || 0);
      this.renderRangeState();
      this.jumpToVerseAndResume(this.range.from)
        .finally(() => { this.handlingRangeBoundary = false; });
      return true;
    }

    this.rangeRepeatCounter = 0;
    this.rangeFinished = true;
    this.rangeSeek = null;
    this.player.pause();
    this.stopProgressLoop();
    this.renderRangeState();
    this.handlingRangeBoundary = false;
    return true;
  }

  restartCurrentVerse() {
    this.player.seek(this.currentVerseStartMs() / 1000);

    if (!this.player.playing()) {
      this.player.play();
    }

    this.startProgressLoop();
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
      this.stopProgressLoop();
    } else if (this.rangeFinished) {
      this.rangeFinished = false;
      this.ayahRepeatCounter = 0;
      this.rangeRepeatCounter = 0;
      this.awaitRangeSeek(this.segmentsData[this.range.from]?.time_from || 0);
      this.renderRangeState();
      this.jumpToVerseAndResume(this.range.from);
    } else {
      if (this.seekOnNextPlay || !this.isPlayerReadyForVerse(this.currentVerseKey)) {
        this.playAyah(this.currentVerseKey);
        this.seekOnNextPlay = false;
      }

      this.player.play();
      this.startProgressLoop();
    }
  }

  formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds || 0));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const pad = (value) => (value < 10 ? `0${value}` : `${value}`);

    // Gapless surah audio runs for hours, so hh:mm:ss is clearer than 136:00.
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
  }
}

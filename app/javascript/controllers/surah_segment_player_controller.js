import SegmentPlayer from './segment_player_controller';
import {QuranUtils} from "../utils/quran";

export default class extends SegmentPlayer {
  async connect() {
    await super.connect();
  }

  initializePlayer() {
    if (this.player) {
      this.player.unload();
    }

    this.playerChapter = this.currentChapter;
    this.player = new Howl({
      src: [this.getAudioUrl()],
      html5: true,
      // A gapless surah can be a two-hour file; only pull metadata up front.
      preload: 'metadata',
      onplay: this.onplay.bind(this),
      onpause: this.onpause.bind(this),
      onend: this.onend.bind(this),
      onload: this.onload.bind(this),
      onloaderror: this.onloaderror.bind(this),
    });
  }

  isPlayerReadyForVerse() {
    return this.player && this.playerChapter === this.currentChapter;
  }

  playAyah(key) {
    if (!this.player || this.playerChapter !== this.currentChapter) {
      this.initializePlayer();
    }

    const segment = this.segmentsData[key]
    if (segment) {
      this.player.seek(segment.time_from / 1000);
      const timeline = this.timelines?.[this.currentChapter] || [];
      this.currentPass = timeline.find((entry) => entry[0] === key && entry[1] === 0) ||
        [key, 0, segment.time_from, segment.time_to];
      this.playWindowEndMs = null;

      if (this.player.state() === 'loaded') {
        this.updateTotalDuration();
      }
    }
  }

  // The recitation pass playing at `time`, from the API's `timeline`
  // ([verseKey, pass, fromMs, toMs] in recitation order). A reciter can go
  // back to an earlier ayah (27, 28, then 27 again), so the ayah at a moment
  // can't be found from the ayah windows alone.
  findPassAtTime(time) {
    const timeline = this.timelines?.[this.currentChapter] || [];

    let left = 0;
    let right = timeline.length - 1;

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const [, , from, to] = timeline[mid];

      if (time < from) {
        right = mid - 1;
      } else if (time > to) {
        left = mid + 1;
      } else {
        return timeline[mid];
      }
    }

    return null;
  }

  findAyahKeyAtTime(time) {
    return this.findPassAtTime(time)?.[0] || null;
  }

  // Range and ayah-repeat boundaries. An ayah followed by returns (28, then
  // 27 and 28 again) is one block: it ends after the last return and repeats
  // from its first pass, so a range never stops or advances mid-return.
  currentVerseStartMs() {
    return this.currentBlock()?.startMs ?? super.currentVerseStartMs();
  }

  currentVerseEndMs() {
    return this.currentBlock()?.endMs ?? super.currentVerseEndMs();
  }

  currentBlock() {
    const timeline = this.timelines?.[this.currentChapter] || [];
    const pass = this.currentPass;
    if (!pass || pass[0] !== this.currentVerseKey) return null;

    let index = timeline.indexOf(pass);
    if (index < 0) return null;

    let first = index;
    while (first > 0 && timeline[first][1] > 0) first--;

    let last = index;
    while (last + 1 < timeline.length && timeline[last + 1][1] > 0) last++;

    return { startMs: timeline[first][2], endMs: timeline[last][3] };
  }

  // Word timings of one pass: 0 is the ayah's `segments`, N is `repeats[N - 1]`.
  passSegments(verseKey, pass) {
    const verse = this.segmentsData[verseKey];
    if (!verse) return [];
    return (pass ? verse.repeats?.[pass - 1]?.segments : verse.segments) || [];
  }

  async updateVerse(time) {
    const current = this.currentPass;
    if (current && current[0] === this.currentVerseKey && time >= current[2] && time <= current[3]) {
      return
    }

    const pass = this.findPassAtTime(time);
    if (!pass) return;

    this.currentPass = pass;
    if (pass[0] !== this.currentVerseKey) await this.jumpToVerse(pass[0]);
  }

  findSegmentAtTime(time) {
    const pass = this.currentPass && this.currentPass[0] === this.currentVerseKey ? this.currentPass[1] : 0;
    const segments = this.passSegments(this.currentVerseKey, pass);
    if (!segments.length) return null;

    let left = 0;
    let right = segments.length - 1;

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const segment = segments[mid];

      if (time < segment[1]) {
        right = mid - 1;
      } else if (time > segment[2]) {
        left = mid + 1;
      } else {
        return segment; // time is within segment range
      }
    }

    return null;
  }

  getAudioUrl() {
    return this.audioData.url
  }

  async loadSegments(verseKey) {
    const verseData = this.segmentsData[verseKey];
    if (verseData?.segments)
      return

    const parts = verseKey.split(":");
    const ayahCount = QuranUtils.getSurahAyahCount(parts[0]);
    // The endpoint paginates (10 per page by default) and ignores from/to, so
    // ask for the whole surah in one page — seeking needs every segment.
    const url = `/api/v1/audio/surah_segments/${this.recitation}?surah=${parts[0]}&per_page=${ayahCount}`;

    const response = await fetch(url);
    const data = await response.json();

    this.audioData = data.audio;

    this.segmentsData = {
      ...this.segmentsData,
      ...data.segments
    };

    this.timelines = {
      ...this.timelines,
      [parseInt(parts[0], 10)]: data.timeline || this.windowsTimeline(data.segments)
    };
  }

  // Older responses without `timeline`: one pass per ayah from its window.
  windowsTimeline(segments) {
    return Object.entries(segments || {})
      .map(([key, verse]) => [key, 0, verse.time_from, verse.time_to])
      .sort((a, b) => a[2] - b[2]);
  }
}
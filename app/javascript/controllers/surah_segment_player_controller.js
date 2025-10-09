import SegmentPlayer from './segment_player_controller';
import {QuranUtils} from "../utils/quran";

export default class extends SegmentPlayer {
  async connect() {
    await super.connect();
  }

  initializePlayer() {
    this.player = new Howl({
      src: [this.getAudioUrl()],
      html5: true,
      onplay: this.onplay.bind(this),
      onpause: this.onpause.bind(this),
      onend: this.onend.bind(this),
      onload: this.onload.bind(this),
      onloaderror: this.onloaderror.bind(this),
    });
  }

  playAyah(key) {
    const segment = this.segmentsData[key]
    if (segment)
      this.player.seek(segment.time_from / 1000);
  }

  findAyahKeyAtTime(time) {
    const segments = this.segmentsData

    let left = 1;
    let right = QuranUtils.getSurahAyahCount(this.currentChapter);

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const key = `${this.currentChapter}:${mid}`;
      const segment = segments[key];

      if (!segment) {
        left = mid + 1;
        continue;
      }

      const {time_from, time_to} = segment;

      if (time < time_from) {
        right = mid - 1;
      } else if (time > time_to) {
        left = mid + 1;
      } else {
        return key;
      }
    }

    return null;
  }

  updateVerse(time) {
    const segments = this.segmentsData[this.currentVerseKey];
    if (segments && time >= segments.time_from && time <= segments.time_to) {
      return
    }

    const key = this.findAyahKeyAtTime(time);

    if (!key) return;
    this.currentVerseKey = key;
    this.jumpToVerse(key);
  }

  findSegmentAtTime(time) {
    const segments = this.segmentsData[this.currentVerseKey]?.segments || [];
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
    const verseData = this.segmnetsData[verseKey];
    if (verseData?.segments)
      return

    const parts = verseKey.split(":");
    const url = `/api/v1/audio/surah_segments/${this.recitation}?from=5&surah=${parts[0]}&from=${parts[1]}`;

    const response = await fetch(url);
    const data = await response.json();

    this.audioData = data.audio;

    this.segmentsData = {
      ...this.segmentsData,
      ...data.segments
    };
  }
}
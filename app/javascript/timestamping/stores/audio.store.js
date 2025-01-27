import { defineStore } from 'pinia';
import { playAyah } from '../helper/audio';

export const useAudioStore = defineStore('audio', {
  state: () => ({
    src: null,
    isPlaying: false,
    playbackSpeed: 1,
    currentTime: 0,
    duration: 0,
    quranicAudioUrl: null,
    fromFile: false,
    isLoopingAyah: false,
    isLoopingWord: false,
    wordLoopTime: -1,
    lockAyah: false,
    autoPlay: false
  }),
  actions: {
    setSource(payload) {
      this.src = payload.url;
      this.fromFile = payload.fromFile;
    },
    togglePlay() {
      this.isPlaying = !this.isPlaying;
      if (this.isPlaying) playAyah();
      else if (player) player.pause();
    },
    setPlaybackSpeed(speed) {
      this.playbackSpeed = speed;
      if (player) player.playbackRate = speed;
    },
    toggleAyahLoop() {
      this.isLoopingAyah = !this.isLoopingAyah;
    },
    setCurrentTime(time) {
      this.currentTime = time;
    }
  }
});
<template>
  <div class="tw-flex tw-flex-wrap tw-gap-4">
    <div class="tw-w-full">
      <h3 class="tw-flex tw-items-center">
        <span class="tw-flex-grow tw-text-xl tw-font-bold">Select Audio</span>
        <button class="tw-px-4 tw-py-2 tw-bg-cyan-600 tw-text-white tw-text-sm tw-font-medium tw-rounded tw-transition-colors hover:tw-bg-cyan-700" @click="loadAudio">
          Load Audio Data!
        </button>
      </h3>
    </div>

    <div class="tw-w-full md:tw-w-[calc(50%-0.5rem)]">
      <div class="tw-space-y-1">
        <input
            type="text"
            class="tw-w-full tw-px-3 tw-py-2 tw-text-sm tw-border tw-border-gray-300 tw-rounded-md tw-focus:tw-outline-none tw-focus:tw-ring-2 tw-focus:tw-ring-blue-500"
            ref="audioUrl"
            placeholder="Audio url"
            :value="quranicAudioUrl"
        />
        <div class="tw-text-xs tw-text-gray-500">Enter file URL</div>
      </div>
    </div>

    <div class="tw-w-full md:tw-w-[calc(50%-0.5rem)]">
      <div class="tw-space-y-1">
        <input type="file" class="tw-w-full tw-px-3 tw-py-1.5 tw-text-sm tw-border tw-border-gray-300 tw-rounded-md tw-cursor-pointer file:tw-mr-4 file:tw-py-1 file:tw-px-4 file:tw-rounded file:tw-border-0 file:tw-text-sm file:tw-font-semibold file:tw-bg-blue-50 file:tw-text-blue-700 hover:file:tw-bg-blue-100" ref="audioFile"/>
        <div class="tw-text-xs tw-text-gray-500">
          Or Select Audio file

          <span class="tw-text-blue-600 tw-font-medium" v-if="fromFile">
            Loaded
          </span>
        </div>
      </div>
    </div>

    <div :class="[audioSrc ? 'tw-w-full tw-mt-4' : 'tw-hidden']">
      <audio ref="audio" :src="audioSrc" id="player" controls class="tw-w-full"></audio>
    </div>
  </div>
</template>

<script>
import {mapState} from "vuex";
import {playAyah} from "../helper/audio";

export default {
  name: "SelectAudioSrc",
  data() {
    return {
      audio: null,
    };
  },
  created() {
    // https://v3.vuejs.org/api/computed-watch-api.html#watching-a-single-source
    this.unwatchVerse = this.$store.watch(
        (state, getters) => state.currentAyahTimeFrom,

        (newValue, _) => {
          const shouldSeek = newValue >= 0 && (
            this.$store.state.audioType === 'ayah' || 
            this.$store.state.isManualAyahChange
          );
          
          if (shouldSeek) {
            player.currentTime = newValue / 1000;
          }
        },
    );

    this.unwatchPlaybackSpeed = this.$store.watch(
        (state, getters) => state.playbackSpeed,

        (newValue, _) => {
          if (newValue >= 0) {
            player.playbackRate = newValue;
          }
        },
    );
  },
  beforeDestroy() {
    this.unwatchVerse();
    this.unwatchPlaybackSpeed();
  },
  mounted() {
    const audio = this.$refs.audio;

    audio.addEventListener("loadstart", this.onLoadStart);
    audio.addEventListener("canplay", this.audioReady);
    audio.addEventListener("error", this.onLoadError);
    audio.addEventListener("timeupdate", this.onPlayerTick);
    audio.addEventListener("pause", this.onPause);
    audio.addEventListener("play", this.onPlay);
    audio.addEventListener("seeked", this.onSeek);
    audio.addEventListener("waiting", this.onBuffering);
    audio.addEventListener("ended", this.onEnd);
    audio.addEventListener("playing", this.onPlay);
    this.audio = audio;
  },
  methods: {
    loadAudio() {
      const inputFile = this.$refs.audioFile.files[0];
      const audioUrl = this.$refs.audioUrl.value;

      if (inputFile) {
        const url = URL.createObjectURL(inputFile);
        this.$store.commit("SET_AUDIO_SOURCE", {url: url, fromFile:  true});
      } else if (audioUrl.length > 0) {
        this.$store.commit("SET_AUDIO_SOURCE", {url: audioUrl, fromFile: false});
      } else {
        this.$store.commit("SET_ALERT", {
          text: "Please select Audio file or use QuranicAudio URL",
        });
      }
    },
    onLoadStart() {
      this.$store.commit("SET_ALERT", {text: "Loading audio"});
    },
    audioReady() {
      if (this.audioType == 'ayah' && this.autoPlay && !this.lockAyah) {
        playAyah()
      }

      this.$store.commit("SET_ALERT", {text: null});
    },
    onLoadError() {
      this.$store.commit("SET_ALERT", {
        text: "Sorry we couldn't load the audio.",
      });
    },
    onPlayerTick(event) {
      this.$store.dispatch("SET_TIMESTAMP", {timestamp: event.target.currentTime * 1000});
    },
    onSeek(event) {
      this.$store.dispatch("SET_TIMESTAMP", {timestamp: event.target.currentTime * 1000});
    },
    onPause() {
      this.$store.commit("SET_PLAYING", {value: false});
    },
    onPlay() {
      this.$store.commit("SET_PLAYING", {value: true});
    },
    onBuffering() {
      this.$store.commit("SET_ALERT", {text: "Buffering"});
    },
    onEnd() {
      if (this.audioType == 'ayah')
        this.$store.commit("SET_AYAH_ENDED");
      else
        this.$store.commit("SET_SURAH_ENDED");
    }
  },
  computed: {
    ...mapState([
      "quranicAudioUrl",
      "audioSrc",
      "verseSegment",
      "currentVerseKey",
      "playBackSpeed",
      "audioType",
      "playing",
      "autoPlay",
      "lockAyah",
      "fromFile",
    ]),
  },
};
</script>

<template>
  <div class="flex flex-wrap gap-4">
    <div class="w-full">
      <h3 class="flex items-center">
        <span class="flex-grow text-xl font-bold">Select Audio</span>
        <button class="px-4 py-2 bg-cyan-600 text-white text-sm font-medium rounded transition-colors hover:bg-cyan-700" @click="loadAudio">
          Load Audio Data!
        </button>
      </h3>
    </div>

    <div class="w-full md:w-[calc(50%-0.5rem)]">
      <div class="space-y-1">
        <input
            type="text"
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            ref="audioUrl"
            placeholder="Audio url"
            :value="quranicAudioUrl"
        />
        <div class="text-xs text-gray-500">Enter file URL</div>
      </div>
    </div>

    <div class="w-full md:w-[calc(50%-0.5rem)]">
      <div class="space-y-1">
        <input type="file" class="w-full px-3 py-1.5 text-sm border border-gray-300 rounded-md cursor-pointer file:mr-4 file:py-1 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" ref="audioFile"/>
        <div class="text-xs text-gray-500">
          Or Select Audio file

          <span class="text-blue-600 font-medium" v-if="fromFile">
            Loaded
          </span>
        </div>
      </div>
    </div>

    <div :class="[audioSrc ? 'w-full mt-4' : 'hidden']">
      <audio ref="audio" :src="audioSrc" id="player" controls class="w-full"></audio>
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

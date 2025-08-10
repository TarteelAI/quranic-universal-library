<template>
  <div class="row">
    <div class="col-12">
      <h3 class="d-flex">
        <span class="flex-grow-1">Select Audio</span>
        <button class="btn btn-info" @click="loadAudio">
          Load Audio Data!
        </button>
      </h3>
    </div>

    <div class="col-6">
      <div class="form-group">
        <input
            type="text"
            class="form-control"
            ref="audioUrl"
            placeholder="Audio url"
            :value="quranicAudioUrl"
        />
        <div class="form-text text-muted">Enter file URL</div>
      </div>
    </div>

    <div class="col-6">
      <div class="form-group">
        <input type="file" class="form-control" ref="audioFile"/>
        <div class="form-text text-muted">
          Or Select Audio file

          <span class="text-primary" v-if="fromFile">
            Loaded
          </span>
        </div>
      </div>
    </div>

    <div :class="[audioSrc ? 'col-12 player-wrapper' : 'd-none']">
      <audio ref="audio" :src="audioSrc" id="player" controls class="w-100"></audio>
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

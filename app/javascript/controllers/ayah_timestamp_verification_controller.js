import { Controller } from "@hotwired/stimulus";
import { Howl } from "howler";

export default class extends Controller {
  static targets = [
    "playButton",
    "playIcon",
    "loopButton",
    "currentTime",
    "totalTime",
    "progress",
    "error",
    "verseKey",
  ];

  static values = {
    audioUrl: String,
    timeFrom: Number,
    timeTo: Number,
    verseKey: String,
  };

  connect() {
    this.player = null;
    this.isPlaying = false;
    this.loopEnabled = false;
    this.rafId = null;
    this.windowStartSec = this.timeFromValue / 1000;
    this.windowEndSec = this.timeToValue / 1000;
    this.windowDurationSec = Math.max(
      this.windowEndSec - this.windowStartSec,
      0.01,
    );

    if (this.hasTotalTimeTarget) {
      this.totalTimeTarget.textContent = this.formatTime(
        this.windowDurationSec,
      );
    }

    this.initializePlayer();
  }

  disconnect() {
    this.stopProgress();
    if (this.player) {
      this.player.unload();
      this.player = null;
    }
  }

  initializePlayer() {
    if (!this.audioUrlValue) {
      this.showError("Audio URL is missing for this ayah.");
      return;
    }

    this.player = new Howl({
      src: [this.audioUrlValue],
      html5: true,
      onplay: () => this.onPlay(),
      onpause: () => this.onPause(),
      onend: () => this.onNaturalEnd(),
      onload: () => this.onLoad(),
      onloaderror: () =>
        this.showError("Failed to load audio. Try another ayah."),
      onplayerror: () => this.showError("Failed to play audio. Try again."),
    });
  }

  togglePlay() {
    if (!this.player) return;

    if (this.isPlaying) {
      this.player.pause();
      return;
    }

    this.playWindow();
  }

  playWindow() {
    if (!this.player) return;

    this.hideError();
    this.player.seek(this.windowStartSec);
    this.player.play();
  }

  toggleLoop() {
    this.loopEnabled = !this.loopEnabled;
    if (this.hasLoopButtonTarget) {
      this.loopButtonTarget.setAttribute(
        "aria-pressed",
        String(this.loopEnabled),
      );
      this.loopButtonTarget.classList.toggle("bg-blue-100", this.loopEnabled);
      this.loopButtonTarget.classList.toggle("text-blue-700", this.loopEnabled);
    }
  }

  onLoad() {
    if (this.hasTotalTimeTarget) {
      this.totalTimeTarget.textContent = this.formatTime(
        this.windowDurationSec,
      );
    }
  }

  onPlay() {
    this.isPlaying = true;
    this.setPlayIcon(true);
    this.startProgress();
  }

  onPause() {
    this.isPlaying = false;
    this.setPlayIcon(false);
    this.stopProgress();
  }

  onNaturalEnd() {
    // Full-file end should still respect the clipped window UX.
    this.handleWindowEnd();
  }

  startProgress() {
    this.stopProgress();
    const tick = () => {
      if (!this.player || !this.isPlaying) return;

      const current = this.player.seek() || 0;
      if (current >= this.windowEndSec) {
        this.handleWindowEnd();
        return;
      }

      const elapsed = Math.max(current - this.windowStartSec, 0);
      const percent = Math.min((elapsed / this.windowDurationSec) * 100, 100);

      if (this.hasCurrentTimeTarget) {
        this.currentTimeTarget.textContent = this.formatTime(elapsed);
      }
      if (this.hasProgressTarget) {
        this.progressTarget.style.width = `${percent}%`;
      }

      this.rafId = requestAnimationFrame(tick);
    };

    this.rafId = requestAnimationFrame(tick);
  }

  handleWindowEnd() {
    this.stopProgress();

    if (this.loopEnabled) {
      this.playWindow();
      return;
    }

    if (this.player) {
      this.player.pause();
      this.player.seek(this.windowStartSec);
    }

    this.isPlaying = false;
    this.setPlayIcon(false);

    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.formatTime(
        this.windowDurationSec,
      );
    }
    if (this.hasProgressTarget) {
      this.progressTarget.style.width = "100%";
    }
  }

  stopProgress() {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  setPlayIcon(playing) {
    if (!this.hasPlayIconTarget) return;
    this.playIconTarget.classList.toggle("fa-pause", playing);
    this.playIconTarget.classList.toggle("fa-play", !playing);
  }

  showError(message) {
    if (!this.hasErrorTarget) return;
    this.errorTarget.textContent = message;
    this.errorTarget.classList.remove("hidden");
  }

  hideError() {
    if (!this.hasErrorTarget) return;
    this.errorTarget.textContent = "";
    this.errorTarget.classList.add("hidden");
  }

  formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds));
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  }
}

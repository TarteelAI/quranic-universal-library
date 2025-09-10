import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const audioElement = document.getElementById('audio-element');
    const audioPlayer = document.getElementById('audio-player');
    const segmentInfo = document.getElementById('current-segment-info');
    debugger

    document.querySelectorAll('.play-audio-btn').forEach(button => {
      button.addEventListener('click', (event)=> {
        const el = event.target
        const {
          startTime,
          endTime,
          surah,
          ayah,
          audioUrl
        } = el.dataset;

        audioElement.src = audioUrl;

        audioPlayer.style.display = 'block';
        segmentInfo.textContent = `Surah ${surah}, Ayah ${ayah} (${this.formatTime(startTime)} - ${this.formatTime(endTime)})`;

        audioElement.addEventListener('loadeddata', function () {
          audioElement.currentTime = parseInt(startTime) / 1000;
          audioElement.play();

          const checkTime = setInterval(() => {
            if (audioElement.currentTime >= parseInt(endTime) / 1000) {
              audioElement.pause();
              clearInterval(checkTime);
            }
          }, 100);
        });

        audioElement.addEventListener('error', function () {
          console.error('Error loading audio:', audioUrl);
          segmentInfo.textContent = `Error loading audio for Surah ${surah}, Ayah ${ayah}`;
        });
      });
    });
  }

  formatTime(milliseconds) {
    const seconds = Math.floor(parseInt(milliseconds) / 1000);
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }
}
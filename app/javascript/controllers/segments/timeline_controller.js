import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.isPlaying = false;
    this.playingSegment = null;
    this.currentlyPlayingWord = null;
    this.ayahWords = new Map(); // Store ayah number -> array of word elements
    this.currentAyahWords = null; // Store current ayah words for highlighting
    this.currentAyahTiming = null; // Store current ayah timing data
    this.ayahTimingData = null; // Store ayah timing data
    this.segmentEndTime = null;
    this.segmentUpdateListener = null; // Store reference to segment-specific listener
    this.isSegmentPlay = false; // Track if we're in segment play mode
    this.originalAudioSrc = null; // Store original audio URL

    this.el = $(this.element);
    this.player = this.element.querySelector('#player');
    this.jumpToInput = this.element.querySelector('#jump-to-input');
    this.jumpToButton = this.element.querySelector('#jump-to-button');
    this.fileInput = this.element.querySelector('#audio-file-input');
    this.resetAudioButton = this.element.querySelector('#reset-audio-button');
    this.dropZone = this.element.querySelector('#audio-drop-zone');

    const {ayah} = this.element.dataset;
    if (ayah) {
      const ayahToJump = this.element.querySelector(`[data-ayah="${ayah}"]`);
      if (ayahToJump)
        ayahToJump.scrollIntoView({behavior: 'smooth', block: 'center'})
    }

    this.el.find('.play-segment').on('click', this.playSegment.bind(this))
    this.player.addEventListener('timeupdate', this.updatePlayerProgress.bind(this));
    this.player.addEventListener('play', this.handlePlay.bind(this));
    this.player.addEventListener('pause', this.handlePause.bind(this));
    this.player.addEventListener('ended', this.handleEnded.bind(this));

    this.originalAudioSrc = this.player.src;
    this.initializeJumpTo();
    this.initializeFileInput();
    this.initializeAyahWords();
    this.loadAyahTimingData();
  }

  handlePlay() {
    this.isPlaying = true;
  }

  handlePause() {
    this.isPlaying = false;
  }

  handleEnded() {
    this.isPlaying = false;
    this.cleanupSegmentPlay();
    this.clearWordHighlight();
  }

  initializeJumpTo() {
    if (this.jumpToButton) {
      this.jumpToButton.addEventListener('click', this.jumpToTime.bind(this));
    }

    if (this.jumpToInput) {
      this.jumpToInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
          this.jumpToTime();
        }
      });
    }
  }

  initializeFileInput() {
    if (this.fileInput) {
      this.fileInput.addEventListener('change', this.handleFileSelection.bind(this));
    }

    if (this.resetAudioButton) {
      this.resetAudioButton.addEventListener('click', this.resetToOriginalAudio.bind(this));
    }

    // Initialize drag and drop
    this.initializeDragAndDrop();
  }

  initializeDragAndDrop() {
    if (!this.dropZone) return;

    // Make drop zone clickable to trigger file input
    this.dropZone.addEventListener('click', () => {
      if (this.fileInput) {
        this.fileInput.click();
      }
    });

    // Add cursor pointer style
    this.dropZone.style.cursor = 'pointer';

    // Prevent default drag behaviors on the entire document
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      document.addEventListener(eventName, this.preventDefaults.bind(this), false);
    });

    // Highlight drop zone when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      this.dropZone.addEventListener(eventName, this.highlight.bind(this), false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      this.dropZone.addEventListener(eventName, this.unhighlight.bind(this), false);
    });

    // Handle dropped files
    this.dropZone.addEventListener('drop', this.handleDrop.bind(this), false);
  }

  preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  highlight() {
    this.dropZone.classList.add('drag-over');
  }

  unhighlight() {
    this.dropZone.classList.remove('drag-over');
  }

  handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;

    if (files.length > 0) {
      const file = files[0];
      this.processAudioFile(file);
    }
  }

  handleFileSelection(event) {
    const file = event.target.files[0];
    if (!file) return;

    this.processAudioFile(file);
  }

  processAudioFile(file) {
    // Validate file type
    if (!file.type.startsWith('audio/')) {
      alert('Please select a valid audio file.');
      return;
    }

    // Clean up any current playback
    this.player.pause();
    this.cleanupSegmentPlay();
    this.clearWordHighlight();

    // Create object URL for the file
    const fileURL = URL.createObjectURL(file);

    // Update audio source
    this.player.src = fileURL;
    this.player.load(); // Reload the audio element

    console.debug('Audio source changed to local file:', file.name);

    // Show reset button
    if (this.resetAudioButton) {
      this.resetAudioButton.style.display = 'inline-block';
    }

    // Show file name
    this.updateFileNameDisplay(file.name);

    // Update file input to show the file (for consistency)
    if (this.fileInput) {
      // Create a new FileList-like object (Note: FileList is read-only, so we can't directly set it)
      // But we can at least clear any validation states
      this.fileInput.setCustomValidity('');
    }
  }

  resetToOriginalAudio() {
    if (!this.originalAudioSrc) {
      console.warn('No original audio source available');
      return;
    }

    // Clean up any current playback
    this.player.pause();
    this.cleanupSegmentPlay();
    this.clearWordHighlight();

    // Reset to original source
    this.player.src = this.originalAudioSrc;
    this.player.load();

    // Clear file input
    if (this.fileInput) {
      this.fileInput.value = '';
    }

    // Hide reset button
    if (this.resetAudioButton) {
      this.resetAudioButton.style.display = 'none';
    }

    // Clear file name display
    this.updateFileNameDisplay(null);

    console.debug('Audio source reset to original URL');
  }

  updateFileNameDisplay(fileName) {
    const fileNameElement = this.element.querySelector('#selected-file-name');
    if (fileNameElement) {
      if (fileName) {
        fileNameElement.textContent = `Selected: ${fileName}`;
        fileNameElement.style.display = 'block';
      } else {
        fileNameElement.style.display = 'none';
      }
    }
  }

  jumpToTime() {
    if (!this.jumpToInput || !this.player) return;

    const milliseconds = parseInt(this.jumpToInput.value);
    if (isNaN(milliseconds) || milliseconds < 0) {
      console.warn('Invalid time value:', this.jumpToInput.value);
      return;
    }

    const seconds = milliseconds / 1000;
    this.player.currentTime = seconds;

    console.debug(`Jumped to ${milliseconds}ms (${seconds}s)`);

    // Clean up any segment play state
    this.cleanupSegmentPlay();
    this.clearWordHighlight();

    // Find and set current ayah for highlighting
    if (this.ayahTimingData) {
      this.findCurrentAyahFromTiming();
    }
  }

  loadAyahTimingData() {
    const timingDataElement = document.getElementById('ayah-timing-data');
    if (timingDataElement) {
      try {
        this.ayahTimingData = JSON.parse(timingDataElement.textContent);
      } catch (e) {
        console.error('Failed to parse ayah timing data:', e);
        this.ayahTimingData = {};
      }
    }
  }

  initializeAyahWords() {
    // Group word elements by their ayah
    this.element.querySelectorAll('[data-ayah]').forEach(ayahElement => {
      const ayahNumber = ayahElement.dataset.ayah;
      const words = ayahElement.querySelectorAll('.words .play-segment');
      this.ayahWords.set(ayahNumber, Array.from(words));
    });
  }

  cleanupSegmentPlay() {
    // Remove segment-specific listener
    if (this.segmentUpdateListener) {
      this.player.removeEventListener('timeupdate', this.segmentUpdateListener);
      this.segmentUpdateListener = null;
    }

    // Clear segment state
    this.isSegmentPlay = false;
    this.playingSegment = null;
    this.segmentEndTime = null;
  }

  playSegment(event) {
    const el = event.target;
    const start = parseFloat(el.dataset.start) / 1000;
    const end = parseFloat(el.dataset.end) / 1000;

    // Validate timing data
    if (isNaN(start) || isNaN(end)) {
      console.warn('Invalid segment timing data:', el.dataset.start, el.dataset.end);
      return;
    }

    // If clicking the same segment while playing, pause it
    if (this.isPlaying && this.playingSegment === el) {
      this.player.pause();
      this.cleanupSegmentPlay();
      this.clearWordHighlight();
      return;
    }

    this.cleanupSegmentPlay();

    this.isSegmentPlay = true;
    this.playingSegment = el;
    this.segmentEndTime = end;
    this.isFullAyahPlay = el.dataset.playAyah !== undefined;

    this.segmentUpdateListener = () => {
      if (this.player.currentTime >= this.segmentEndTime) {
        this.player.pause();
        this.cleanupSegmentPlay();
        this.clearWordHighlight();
      }
    };
    this.player.addEventListener('timeupdate', this.segmentUpdateListener);

    this.player.currentTime = start;
    this.player.play(); // This will trigger handlePlay()
    this.clearWordHighlight();

    if (this.isFullAyahPlay) {
      const ayahElement = el.closest('[data-ayah]');
      if (ayahElement) {
        const ayahNumber = ayahElement.dataset.ayah;
        this.currentAyahWords = this.ayahWords.get(ayahNumber);
        this.currentAyahTiming = this.ayahTimingData[ayahNumber];
      }
    } else {
      // For individual word segments, highlight immediately
      this.highlightWord(el);
    }
  }

  updatePlayerProgress() {
    const currentTime = this.player.currentTime * 1000;

    // If we don't have currentAyahWords set and we're not in segment play,
    // try to find the current ayah based on timing
    const lastWord = this.currentAyahTiming?.words?.at(-1);
    if (!this.currentAyahTiming || (lastWord && currentTime > lastWord[2])) {
      this.findCurrentAyahFromTiming();
    }

    this.updateWordHighlight();
  }

  findCurrentAyahFromTiming() {
    const currentTime = this.player.currentTime * 1000;

    // Find which ayah we're currently in
    for (const [ayahNumber, timing] of Object.entries(this.ayahTimingData)) {
      if (currentTime >= timing.start_time && currentTime <= timing.end_time) {
        this.currentAyahWords = this.ayahWords.get(ayahNumber);
        this.currentAyahTiming = timing; // Store the timing data for this ayah
        console.debug(`Found current ayah: ${ayahNumber} at time ${currentTime}`);
        break;
      }
    }
  }

  updateWordHighlight() {
    if (!this.currentAyahWords || !this.currentAyahTiming || !this.isPlaying) return;

    const currentTime = this.player.currentTime * 1000;
    const wordIndex = this.binarySearchWord(currentTime);
    
    if (wordIndex !== -1) {
      const wordId = this.currentAyahTiming.words[wordIndex][0];
      const wordToHighlight = this.currentAyahWords[wordId-1];

      if (wordToHighlight !== this.currentlyPlayingWord) {
        this.clearWordHighlight();
        this.highlightWord(wordToHighlight);
      }
    } else {
      console.debug("No word to highlight at", currentTime);
    }
  }

  binarySearchWord(currentTime) {
    const words = this.currentAyahTiming.words;
    let left = 0;
    let right = words.length - 1;
    let result = -1;

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const wordTiming = words[mid];
      const wordStart = wordTiming[1]; // start_time
      const wordEnd = wordTiming[2];   // end_time

      if (currentTime >= wordStart && currentTime < wordEnd) {
        // Found the word that should be highlighted
        result = mid;
        break;
      } else if (currentTime < wordStart) {
        // Current time is before this word, search left half
        right = mid - 1;
      } else {
        // Current time is after this word, search right half
        left = mid + 1;
      }
    }

    return result;
  }

  highlightWord(wordElement) {
    if (this.currentlyPlayingWord) {
      this.currentlyPlayingWord.classList.remove('currently-playing');
    }
    this.currentlyPlayingWord = wordElement;
    wordElement.classList.add('currently-playing');
  }

  clearWordHighlight() {
    if (this.currentlyPlayingWord) {
      this.currentlyPlayingWord.classList.remove('currently-playing');
      this.currentlyPlayingWord = null;
    }

    // Only clear currentAyahWords and currentAyahTiming if we're not in a full ayah segment play
    if (!this.isSegmentPlay || !this.isFullAyahPlay) {
      this.currentAyahWords = null;
      this.currentAyahTiming = null;
    }
  }

  disconnect() {
    this.cleanupSegmentPlay();
    this.clearWordHighlight();

    // Clean up any object URLs to prevent memory leaks
    if (this.player.src && this.player.src.startsWith('blob:')) {
      URL.revokeObjectURL(this.player.src);
    }
  }
}
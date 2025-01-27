// helper/audio.js
export const createAudioManager = (stores) => {
  const { audioStore, surahStore, segmentsStore, uiStore } = stores;
  let player = window.player || document.getElementById('player');

  const handleTimeUpdate = () => {
    audioStore.currentTime = player.currentTime * 1000;

    // Update current word highlighting
    const currentTimeMs = audioStore.currentTime;
    const currentVerse = surahStore.currentVerseKey;

    if (surahStore.audioType === 'ayah') {
      const word = findVerseSegment(
        currentTimeMs,
        segmentsStore.original[currentVerse],
        segmentsStore.currentWord
      );
      segmentsStore.currentWord = word;
    } else {
      const result = findSegment(
        currentTimeMs,
        segmentsStore.original,
        surahStore.currentVerseNumber,
        surahStore.chapter,
        segmentsStore.currentWord,
        surahStore.versesCount
      );
      segmentsStore.currentWord = result.word;
    }
  };

  const handleEnded = () => {
    if (audioStore.isLoopingAyah) {
      player.currentTime = segmentsStore.current.timestamp_from / 1000;
      player.play();
    } else if (!audioStore.lockAyah) {
      surahStore.loadAyah(surahStore.currentVerseNumber + 1);
    }
  };

  const setupEventListeners = () => {
    player.addEventListener('timeupdate', handleTimeUpdate);
    player.addEventListener('ended', handleEnded);
    player.addEventListener('error', (e) => {
      uiStore.showAlert(`Audio error: ${e.target.error.message}`);
    });
  };

  const play = async () => {
    try {
      await player.play();
      audioStore.isPlaying = true;
    } catch (error) {
      if (error.name === 'NotAllowedError') {
        uiStore.showAlert('Please interact with the page first to play audio');
      }
    }
  };

  const pause = () => {
    player.pause();
    audioStore.isPlaying = false;
  };

  const seek = (timeMs) => {
    player.currentTime = timeMs / 1000;
  };

  const setSource = (url) => {
    player.src = url;
    player.load();
  };

  // Initialize
  setupEventListeners();

  return {
    player,
    play,
    pause,
    seek,
    setSource
  };
};

export const playAyah = () => {
  const audioStore = useAudioStore();
  const surahStore = useSurahStore();
  const segmentsStore = useSegmentsStore();

  if (!audioStore.src) return;

  // Handle word looping
  if (audioStore.isLoopingWord && segmentsStore.current) {
    const word = segmentsStore.current.segments[segmentsStore.currentWord - 1];
    if (word) {
      audioStore.player.currentTime = word[1] / 1000;
    }
  }

  // Handle ayah looping
  if (audioStore.isLoopingAyah && segmentsStore.current) {
    audioStore.player.currentTime = segmentsStore.current.timestamp_from / 1000;
  }

  audioStore.play();
};
const playAyah = () => {
  const audio = typeof player == 'undefined' ? document.getElementById('player') : player;

  if (audio && audio.paused) {
    audio.play().then(() => {
      console.log("Audio is playing");
    }).catch((error) => {
      if (error.name === 'NotAllowedError') {
        console.info("Audio play was blocked. The user hasn't interacted with the document.");
      } else {
        console.error("Error occurred during audio playback: ", error);
      }
    });
  }
};

export {
  playAyah
}
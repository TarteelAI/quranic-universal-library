// helper/findSegment.js

export const findVerseSegment = (currentTime, verseSegments) => {
  if (!verseSegments?.segments) return { word: null };

  const segments = verseSegments.segments;
  let low = 0;
  let high = segments.length - 1;

  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    const [wordNumber, start = 0, end = Infinity] = segments[mid];

    if (currentTime >= start && currentTime <= end) {
      return { word: wordNumber };
    }

    if (currentTime < start) {
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }

  return { word: null };
};

export const findSegment = (currentTime, segments, currentVerse, chapter, versesCount) => {
  let low = 1;
  let high = versesCount;
  let foundVerse = currentVerse;

  // Binary search for verse
  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    const verseKey = `${chapter}:${mid}`;
    const verseSeg = segments[verseKey];

    if (!verseSeg) {
      if (mid < currentVerse) low = mid + 1;
      else high = mid - 1;
      continue;
    }

    if (currentTime < verseSeg.timestamp_from) {
      high = mid - 1;
    } else if (currentTime > verseSeg.timestamp_to) {
      low = mid + 1;
    } else {
      foundVerse = mid;
      break;
    }
  }

  // Find word in verse
  const verseKey = `${chapter}:${foundVerse}`;
  const verseSeg = segments[verseKey];
  if (!verseSeg) return { verse: foundVerse, word: null };

  const wordResult = findVerseSegment(currentTime, verseSeg);
  return { verse: foundVerse, word: wordResult.word };
};
const findSegment = (timestamp, segments, currentVerse, chapter, currentWord, versesCount) => {
  const verse = findVerse(timestamp, segments, currentVerse, chapter, versesCount);

  if (verse) {
    const verseSegment = segments[`${chapter}:${verse}`];

    // Guard against undefined verseSegment (e.g., missing segments, timestamp outside range)
    if (!verseSegment) {
      return {};
    }

    return findSurahVerseSegment(timestamp, verseSegment, verse, currentWord);
  }

  return {};
};

const findVerseSegment = (timestamp, verseSegments, currentWord) => {
  // Guard against undefined verseSegments parameter (e.g. segments[currentVerseKey] miss)
  if (!verseSegments) {
    return {};
  }

  const segments = verseSegments.segments || [];
  let target = {};

  // Binary search for the segment that contains the timestamp
  let left = 0;
  let right = segments.length - 1;

  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    const from = segments[mid][1];
    const to = segments[mid][2];

    if (timestamp >= from && timestamp <= to) {
      // found the word
      target.word = segments[mid][0];
      break;
    } else if (timestamp < from) {
      right = mid - 1;
    } else {
      left = mid + 1;
    }
  }

  return target;
}

const findSurahVerseSegment = (timestamp, verseSegment, verse, currentWord) => {
  // Guard against undefined verseSegment parameter
  if (!verseSegment) {
    return { verse: null, word: null };
  }

  const segments = verseSegment.segments || [];

  let target = {
    verse: verse,
  };

  for (let segment of segments) {
    const from = segment[1];
    const to = segment[2];

    if (timestamp >= from && timestamp <= to) {
      // found the word 
      target.word = segment[0];
      break;
    }
  }

  return target;
}


const findVerse = (timestamp, segments, currentVerse, chapter, totalVerse) => {
  const total = Number(totalVerse);
  if (!Number.isFinite(total) || total < 1) {
    return null;
  }

  let verse = Number(currentVerse) || 1;
  if (verse < 1 || verse > total) {
    return null;
  }

  // Walk towards the verse whose window contains the timestamp. Iterative and
  // bounded by the verse count: a missing verse count or an out of range
  // timestamp used to recurse until the stack blew up.
  for (let step = 0; step <= total; step++) {
    const segment = segments[`${chapter}:${verse}`];
    if (!segment) {
      return null;
    }

    const {
      timestamp_from,
      timestamp_to,
    } = segment;

    if (timestamp >= timestamp_from && timestamp <= timestamp_to) {
      return verse;
    }

    if (timestamp < timestamp_from) {
      if (verse <= 1) {
        return null;
      }
      verse -= 1;
    } else if (timestamp > timestamp_to) {
      if (verse >= total) {
        return null;
      }
      verse += 1;
    } else {
      return null;
    }
  }

  return null;
}

export {
  findSegment,
  findVerseSegment
}
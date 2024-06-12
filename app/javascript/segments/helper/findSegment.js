const findSegment = (timestamp, segments, currentVerse, chapter, currentWord, versesCount) => {
  const verse = findVerse(timestamp, segments, currentVerse, chapter, versesCount);

  if (verse) {
    const verseSegment = segments[`${chapter}:${verse}`];

    return findSurahVerseSegment(timestamp, verseSegment, verse, currentWord);
  }

  return {};
};

const findVerseSegment = (timestamp, verseSegments, currentWord) => {
  const segments = verseSegments.segments || [];

  let target = {
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

const findSurahVerseSegment = (timestamp, verseSegment, verse, currentWord) => {
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
  if (currentVerse) {
    // check if timestamp is still within current ayah 
    const segment = segments[`${chapter}:${currentVerse}`];
    if(!segment) 
      return {}; 

    const {
      timestamp_from,
      timestamp_to,
    } = segment;

    if (timestamp >= timestamp_from && timestamp <= timestamp_to)
      return currentVerse

    if (timestamp < timestamp_from && currentVerse > 0) {
      // go to previous verse
      return findVerse(timestamp, segments, currentVerse - 1, chapter, totalVerse)
    }

    if (timestamp > timestamp_to && currentVerse < totalVerse) {
      // go to previous verse
      return findVerse(timestamp, segments, currentVerse + 1, chapter, totalVerse)
    }
  } else {
    // Loop over all ayah and find one
    return findVerse(timestamp, segments, 1, chapter, totalVerse)
  }
}

export {
  findSegment,
  findVerseSegment
}
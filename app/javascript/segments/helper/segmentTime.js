// Ported from AudioSegmentParser#divide_segment_time / #calculate_word_text_score.
// Letters carrying a madda get a heavier weight so they receive more of the duration.

const DIACRITICS_TO_STRIP = /[ًٌٍَُِّْـٰ]/g;

const LETTER_SCORES = {
  "ٓ": 6,
  "": 4,
  "آّ": 6,
  "ٰ": 4,
  "ۖ": 2,
};

export function normalizeText(text) {
  if (text == null) return "";
  return String(text).replace(DIACRITICS_TO_STRIP, "");
}

export function calculateWordTextScore(text) {
  const base = normalizeText(text).length;

  let diacriticScore = 0;
  for (const char of String(text == null ? "" : text)) {
    diacriticScore += LETTER_SCORES[char] || 0;
  }

  return base + diacriticScore;
}

export function divideSegmentTime(startTime, endTime, texts) {
  if (!texts || texts.length <= 1) return [[startTime, endTime]];

  const totalDuration = endTime - startTime;
  const scores = texts.map((t) => calculateWordTextScore(t));
  const totalScore = scores.reduce((sum, score) => sum + score, 0);

  if (totalScore === 0) return [[startTime, endTime]];

  const result = [];
  let currentStart = startTime;

  scores.forEach((score, i) => {
    const segmentDuration = Math.round((score / totalScore) * totalDuration);
    const segmentEnd = i === scores.length - 1 ? endTime : currentStart + segmentDuration;

    result.push([currentStart, segmentEnd]);
    currentStart = segmentEnd;
  });

  return result;
}

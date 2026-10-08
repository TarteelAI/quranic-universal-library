// Aligning letter segments onto displayed Arabic word text.
//
// The idea: rather than rendering the glyph stored in each letter segment, slice
// the word's own DigitalKhatt text into one piece per segment. Rendering the
// slices as plain inline spans preserves the cursive joining, so the word still
// reads as normal Arabic while a single letter can be highlighted.

// Hamza-carrier letters: the precomposed form a letter segment uses (أ)
// compares equal to the decomposed one DigitalKhatt renders (أ).
export const HAMZA_FORMS = {
  'آ': 'آ',
  'أ': 'أ',
  'ؤ': 'ؤ',
  'إ': 'إ',
  'ئ': 'ئ',
};

// Characters the letter-segment source and the DigitalKhatt text spell
// differently but which denote the same sound: alef maksura for a final yeh,
// the Quranic open tanween forms, the small-high-head sukun, and the alef
// variants. Folded to one spelling for matching only — the displayed text is
// always sliced from the original string.
export const CANONICAL_CP = {
  'ى': 'ي',
  'ی': 'ي',
  'ـ': '',
  'ۡ': 'ْ',
  'ࣰ': 'ً',
  'ࣱ': 'ٌ',
  'ࣲ': 'ٍ',
  'ٱ': 'ا',
  'ٰ': 'ا',
};

export const ARABIC_MARK = /[ً-ٰٟۖ-ۭ࣓-ࣿ]/;

export const canonicalCp = (cp) => (CANONICAL_CP[cp] !== undefined ? CANONICAL_CP[cp] : cp);

// Tested on the RAW codepoints, before canonicalisation: a dagger alef (\u0670)
// is a mark here even though it folds to a plain alef for matching.
const isMarkOnly = (target) => target.every((cp) => ARABIC_MARK.test(cp));

// Expand precomposed hamza carriers so they match either spelling. `index` keeps
// every expanded codepoint pointing back at the original character, so slicing
// never splits one.
//
// NFD would do the expansion but also applies canonical ordering, which reorders
// Quranic mark runs such as shadda + fatha — that both breaks the match and
// corrupts the rendered text, so the expansion is done by hand.
export function expandChars(chars) {
  const out = [];

  chars.forEach((char, index) => {
    const expanded = HAMZA_FORMS[char] || char;
    for (const cp of expanded) out.push({ cp, index });
  });

  return out;
}

// Alignment of a letter-segment list onto the displayed word text.
//
// A segment's `char` is not always a single character: a consonant carrying a
// shadda or sukun is stored as one segment (نّ), so targets are matched as
// codepoint sequences. The segment data also comes from a source whose
// orthography differs from the DigitalKhatt text in places (alef maksura for
// final yeh, plain fatha for an open fathatan, a sukun the mushaf doesn't
// write), so matching is done on canonicalised codepoints and falls back to the
// bare base letter. A letter that still can't be placed is skipped rather than
// failing the whole word — it simply never highlights, while the rest of the
// word stays letter-addressable.
//
// Characters between matches attach to the preceding letter and trailing ones to
// the last letter, so the concatenated slices always reproduce the word exactly —
// nothing is dropped from the display.
//
//   word    displayed text, e.g. "بِسۡمِ"
//   letters [{ char, start, end }, ...] in reading order
//   →       [{ text, start, end }, ...], one per letter, or null
export function alignLetters(word, letters) {
  if (!word || !letters || !letters.length) return null;

  const chars = Array.from(word);
  const expanded = expandChars(chars);
  const slices = letters.map((letter) => ({ text: '', start: letter.start, end: letter.end }));

  // `ei` walks the expanded codepoints, `ci` the original characters; both only
  // move forward, which keeps the slices in reading order.
  let ei = 0;
  let ci = 0;

  const seek = (target, from) => {
    for (let j = from; j + target.length <= expanded.length; j++) {
      if (target.every((cp, k) => canonicalCp(expanded[j + k].cp) === canonicalCp(cp))) return j;
    }
    return -1;
  };

  for (let li = 0; li < letters.length; li++) {
    const target = expandChars(Array.from(letters[li].char || '')).map((e) => e.cp);
    if (!target.length) continue;

    let j = seek(target, ei);
    let len = target.length;

    // A segment that is nothing but diacritics (QUD's char layer gives every
    // harakah its own span) belongs to the letter just consumed, so it may only
    // match AT the cursor. Letting it seek forward is actively harmful: in
    // ٱلْحَمْدُ the lone fatha QUD emits for the alef-wasla's helping vowel would
    // otherwise match the fatha on the ح four characters later, dragging the
    // cursor past لْ and ح and leaving all three unhighlightable. If the mark is
    // not right here, this text does not write it — skip it and move on.
    if (isMarkOnly(target) && j !== ei) j = -1;

    if (j < 0 && target.length > 1) {
      const base = target.filter((cp) => !ARABIC_MARK.test(cp));
      if (base.length) {
        j = seek(base, ei);
        len = base.length;
      }
    }

    if (j < 0) continue;

    const matchStart = expanded[j].index;
    if (matchStart > ci) {
      const attachTo = li === 0 ? 0 : li - 1;
      slices[attachTo].text += chars.slice(ci, matchStart).join('');
    }

    const from = Math.max(matchStart, ci);
    const to = expanded[j + len - 1].index + 1;
    if (to > from) slices[li].text += chars.slice(from, to).join('');

    ci = Math.max(ci, to);
    ei = j + len;
  }

  if (ci < chars.length) {
    slices[slices.length - 1].text += chars.slice(ci).join('');
  }

  return slices;
}

// ---------------------------------------------------------------------------
// Repeated words
// ---------------------------------------------------------------------------
//
// When a reciter backs up and repeats part of an ayah, the word appears several
// times in `segments` and carries a full set of letters per take. The mushaf
// still shows the word once, so the text can only be sliced once — a take is not
// a second word, it is a second set of timings for the same slices.
//
// `alignLetters` on the merged list would place only the first take: its cursor
// only moves forward, so every later take finds nothing left to match and comes
// back with empty slices that can never highlight. Splitting by take first and
// merging the timings afterwards is what keeps both takes addressable.

// Group a word's letters by which take of the word they fall in. `occurrences`
// are the word's [start, end] spans, in the order they were recited. A letter
// that lands in no span (timings that disagree at the edges) joins the last take
// that had already started, so nothing is silently dropped.
export function splitLetterTakes(letters, occurrences) {
  const list = letters || [];
  if (!list.length) return [];

  const spans = (occurrences || [])
    .map((occurrence) => [Number(occurrence[0]), Number(occurrence[1])])
    .filter(([start, end]) => Number.isFinite(start) && Number.isFinite(end))
    .sort((a, b) => a[0] - b[0]);

  if (spans.length < 2) return [list];

  const takes = spans.map(() => []);

  list.forEach((letter) => {
    let index = spans.findIndex(([start, end]) => letter.start >= start && letter.start < end);

    if (index < 0) {
      index = 0;
      for (let i = 0; i < spans.length; i++) {
        if (letter.start >= spans[i][0]) index = i;
      }
    }

    takes[index].push(letter);
  });

  return takes.filter((take) => take.length);
}

// Slices for a word that may have been recited more than once: one slice per
// letter of the displayed text, each carrying a `ranges` list with one entry per
// take. Callers highlight a slice while the clock is inside ANY of its ranges.
//
//   word        displayed text
//   letters     [{ char, start, end }, ...] across every take, in reading order
//   occurrences the word's [start, end] spans, one per take
//   →           [{ text, start, end, ranges: [[start, end], ...] }, ...] or null
//
// A partial take — the reciter starting the word and stopping — is a prefix of
// the full one, so take timings line up with the slices by index. The fullest
// take defines the text partition; nothing is attached beyond where it ends.
export function alignLetterTakes(word, letters, occurrences) {
  const takes = splitLetterTakes(letters, occurrences);
  if (!takes.length) return null;

  const aligned = takes.map((take) => alignLetters(word, take)).filter(Boolean);
  if (!aligned.length) return null;

  const base = aligned.reduce((widest, take) => (take.length > widest.length ? take : widest));

  return base.map((slice, index) => ({
    text: slice.text,
    start: slice.start,
    end: slice.end,
    ranges: aligned
      .map((take) => take[index])
      .filter(Boolean)
      .map((take) => [take.start, take.end]),
  }));
}

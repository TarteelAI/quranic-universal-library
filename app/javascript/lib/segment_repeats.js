// A segment's word list is [[position, startMs, endMs], ...] in RECITATION
// order, so a repeat shows up as a run of positions appearing again later:
//
//   [1,2,3,4, 1,2,3,4,5,6,7,8,9,10,11]
//    └ take 1 ┘ └────── take 2 ──────┘   → words 1–4 repeated
//
// That one shape covers both cases people care about: a few words said twice,
// and a whole ayah started over.

export const PARTIAL = "partial"
export const FULL = "full"

// Every repeated run in one ayah's word list.
//
//   wordSegments [[position, startMs, endMs], ...] in recitation order
//   wordsCount   how many words the ayah actually has, so a run covering all of
//                them can be called a full repeat rather than a long partial one
//   →            [{ fromWord, toWord, full, label, startMs }]
export function findRepeats(wordSegments, wordsCount) {
  const positions = (wordSegments || []).map((segment) => Number(segment[0]))
  const seen = {}
  const found = []
  const seenRanges = {}

  for (let i = 0; i < positions.length; i++) {
    const previous = seen[positions[i]]

    if (previous !== undefined) {
      const length = i - previous

      if (length > 0 && i + length <= positions.length) {
        let identical = true
        for (let k = 0; k < length; k++) {
          if (positions[previous + k] !== positions[i + k]) {
            identical = false
            break
          }
        }

        if (identical) {
          const fromWord = positions[i]
          const toWord = positions[i + length - 1]
          const rangeKey = `${fromWord}-${toWord}`

          if (!seenRanges[rangeKey]) {
            seenRanges[rangeKey] = true
            const full = fromWord === 1 && wordsCount > 0 && toWord >= wordsCount

            found.push({
              fromWord,
              toWord,
              full,
              label: full
                ? `whole ayah (${fromWord}–${toWord})`
                : (fromWord === toWord ? `word ${fromWord}` : `words ${fromWord}–${toWord}`),
              startMs: wordSegments[i] ? Number(wordSegments[i][1]) : null,
            })
          }
        }
      }
    }

    seen[positions[i]] = i
  }

  return found
}

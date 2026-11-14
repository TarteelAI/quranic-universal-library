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
//   →            [{ fromWord, toWord, full, label, startMs, takes }]
//                takes: every time the run was recited, [{ startMs, endMs }] in
//                order, so each one can be played on its own
export function findRepeats(wordSegments, wordsCount) {
  const positions = (wordSegments || []).map((segment) => Number(segment[0]))
  const seen = {}
  const found = []
  const byRange = {}
  const take = (at, length) => {
    const first = wordSegments[at]
    const last = wordSegments[at + length - 1]
    return { startMs: first ? Number(first[1]) : null, endMs: last ? Number(last[2]) : null }
  }

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

        const fromWord = positions[i]
        const toWord = positions[i + length - 1]

        // Alternating takes (1 2 1 2) also match shifted by one word, as a
        // backwards "2–1" run. That is the same repeat seen again, not a new one.
        if (identical && fromWord <= toWord) {
          const rangeKey = `${fromWord}-${toWord}`

          const existing = byRange[rangeKey]

          if (existing) {
            // A third (or later) take of the same run.
            existing.takes.push(take(i, length))
          } else {
            const full = fromWord === 1 && wordsCount > 0 && toWord >= wordsCount
            const entry = {
              fromWord,
              toWord,
              full,
              label: full
                ? `whole ayah (${fromWord}–${toWord})`
                : (fromWord === toWord ? `word ${fromWord}` : `words ${fromWord}–${toWord}`),
              startMs: wordSegments[i] ? Number(wordSegments[i][1]) : null,
              takes: [take(previous, length), take(i, length)],
            }
            byRange[rangeKey] = entry
            found.push(entry)
          }
        }
      }
    }

    seen[positions[i]] = i
  }

  return found
}

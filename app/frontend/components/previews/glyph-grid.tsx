import type { BBox, Font, Glyph } from 'fontkit'
import * as React from 'react'

import type { FontFiles } from '@/types/serializers'

// Glyph names that every font carries but nobody wants to browse.
const RESERVED_GLYPH_NAMES = ['.notdef', '.null', 'nonmarkingreturn', 'NULL', 'CR']
// The first paint is capped so a 6,000-glyph mushaf font does not lock up the tab.
const SHOWN = 600

type Entry = {
  id: number
  glyph: Glyph
  name: string
  char: string
  hex: string | null
  primary: number | undefined
  box: BBox | null
  haystack: string
}

function hex(codePoint: number) {
  return codePoint.toString(16).toUpperCase().padStart(4, '0')
}

// Some fonts ship a zeroed bounding box, so the outline is measured first.
function glyphBox(glyph: Glyph): BBox | null {
  for (const read of [() => glyph.path.bbox, () => glyph.bbox]) {
    try {
      const box = read()
      if (box && box.maxX > box.minX && box.maxY > box.minY) return box
    } catch {
      // A broken outline: try the next source.
    }
  }
  return null
}

// Every glyph in the font, not only the ones a code point reaches, so ligature-only glyphs
// (surah-name fonts, QCF word glyphs) are listed too. Code point order, unmapped glyphs last.
function collectGlyphs(font: Font): Entry[] {
  const codePointsByGlyph = new Map<number, number[]>()
  for (const codePoint of font.characterSet) {
    const glyph = font.glyphForCodePoint(codePoint)
    if (!glyph) continue
    codePointsByGlyph.set(glyph.id, [...(codePointsByGlyph.get(glyph.id) ?? []), codePoint])
  }

  const entries: Entry[] = []
  for (let id = 0; id < font.numGlyphs; id++) {
    let glyph: Glyph | null
    try {
      glyph = font.getGlyph(id)
    } catch {
      continue
    }
    if (!glyph) continue
    const name = glyph.name ?? ''
    if (RESERVED_GLYPH_NAMES.includes(name)) continue

    const codePoints = (codePointsByGlyph.get(id) ?? []).sort((a, b) => a - b)
    // QCF page fonts map each word glyph from an ASCII byte and from its Arabic code point;
    // the Arabic one is what a reader looks for.
    const primary = codePoints.find((codePoint) => codePoint >= 0x0600) ?? codePoints[0]
    entries.push({
      id,
      glyph,
      name,
      char: primary === undefined ? '' : String.fromCodePoint(primary),
      hex: primary === undefined ? null : hex(primary),
      primary,
      box: glyphBox(glyph),
      haystack: [name, `#${id}`, primary === undefined ? '' : String.fromCodePoint(primary)]
        .concat(codePoints.flatMap((codePoint) => [`u+${hex(codePoint)}`, hex(codePoint)]))
        .join(' ')
        .toLowerCase(),
    })
  }

  return entries.sort((a, b) => (a.primary ?? Infinity) - (b.primary ?? Infinity) || a.id - b.id)
}

// The file fontkit reads: TrueType first, as the old Glyphs tab did.
function fileFor(font: FontFiles) {
  const order = ['truetype', 'opentype', 'woff', 'woff2']
  return [...font.sources].sort((a, b) => order.indexOf(a.format) - order.indexOf(b.format))[0]
}

type State = { url: string } & (
  | { status: 'loading' }
  | { status: 'failed'; message: string }
  | { status: 'ready'; glyphs: Entry[] }
)

// Every glyph in the font file, read in the browser with fontkit (loaded only for this view).
export function GlyphGrid({ font }: { font: FontFiles }) {
  const url = fileFor(font)?.url ?? ''
  const [state, setState] = React.useState<State>({ url, status: 'loading' })
  const [query, setQuery] = React.useState('')

  React.useEffect(() => {
    let current = true
    async function load() {
      const response = await fetch(url)
      if (!response.ok) throw new Error(`The font file answered HTTP ${response.status}.`)
      const fontkit = await import('fontkit')
      return collectGlyphs(fontkit.create(new Uint8Array(await response.arrayBuffer())))
    }
    load()
      .then((glyphs) => current && setState({ url, status: 'ready', glyphs }))
      .catch((error: unknown) => current && setState({ url, status: 'failed', message: String(error) }))
    return () => {
      current = false
    }
  }, [url])

  const shown = state.url === url ? state : { url, status: 'loading' as const }
  if (shown.status === 'loading') {
    return (
      <p role="status" className="text-sm text-muted-foreground" data-testid="glyph-grid" data-status="loading">
        Reading the glyphs from the font file…
      </p>
    )
  }
  if (shown.status === 'failed') {
    return (
      <p
        role="status"
        className="rounded-lg bg-warning-subtle p-3 text-sm text-warning"
        data-testid="glyph-grid"
        data-status="failed"
      >
        The glyphs of this font could not be read from {url}. {shown.message}
      </p>
    )
  }

  const needle = query.trim().toLowerCase()
  const matches = needle ? shown.glyphs.filter((entry) => entry.haystack.includes(needle)) : shown.glyphs

  return (
    <div className="flex flex-col gap-4" data-testid="glyph-grid" data-status="ready" data-count={shown.glyphs.length}>
      <div className="flex flex-wrap items-center gap-3 text-sm">
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search by character, name or Unicode (0627, U+FB57)"
          aria-label="Search glyphs"
          className="h-8 w-full max-w-80 rounded-md border bg-card px-2 shadow-xs"
        />
        <span className="text-muted-foreground">
          {matches.length === shown.glyphs.length
            ? `${shown.glyphs.length} glyphs`
            : `${matches.length} of ${shown.glyphs.length} glyphs`}
        </span>
      </div>
      {matches.length === 0 && <p className="text-sm text-muted-foreground">No glyph matches that search.</p>}
      <ul className="grid grid-cols-[repeat(auto-fill,minmax(88px,1fr))] gap-2">
        {matches.slice(0, SHOWN).map((entry) => (
          <GlyphCell key={entry.id} entry={entry} />
        ))}
      </ul>
      {matches.length > SHOWN && (
        <p className="text-sm text-muted-foreground">
          Showing the first {SHOWN} of {matches.length} glyphs. Narrow the search to see the rest.
        </p>
      )}
    </div>
  )
}

function GlyphCell({ entry }: { entry: Entry }) {
  const { box } = entry
  const pad = box ? Math.max(box.maxX - box.minX, box.maxY - box.minY) * 0.12 : 0

  return (
    <li
      className="flex flex-col items-center gap-1 rounded-lg border bg-white p-2 text-black"
      title={entry.name || undefined}
    >
      {box ? (
        <svg
          viewBox={`${box.minX - pad} ${-box.maxY - pad} ${box.maxX - box.minX + 2 * pad} ${box.maxY - box.minY + 2 * pad}`}
          className="h-16 w-full"
          aria-hidden="true"
        >
          <path d={entry.glyph.path.toSVG()} transform="scale(1,-1)" fill="currentColor" />
        </svg>
      ) : (
        <span className="flex h-16 items-center text-[11px] text-neutral-400">no outline</span>
      )}
      <span className="w-full truncate text-center font-mono text-[11px] text-neutral-600">
        {entry.hex ? `U+${entry.hex}` : `#${entry.id}`}
      </span>
    </li>
  )
}

import { ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import type { PreviewsFont, PreviewsScriptSurah } from '@/types/serializers'

// The query-string keys of a preview (Previews::QUERY_KEYS). Each preview sets the keys it reads.
export type PreviewQuery = Partial<Record<'page' | 'surah' | 'from' | 'to' | 'view', string | number>>

export type PreviewNavigation = {
  // Shows another page or range: the URL changes and only the preview prop reloads.
  navigate: (query: PreviewQuery) => void
  // Switches the font view in the URL and the props, without a request.
  showView: (view: PreviewsFont['view'], query: PreviewQuery) => void
  loading: boolean
}

export const selectClass = 'h-8 max-w-56 rounded-md border bg-card px-2 text-sm text-foreground shadow-xs'

export function PreviewToolbar({ children, loading }: { children: React.ReactNode; loading: boolean }) {
  return (
    <div
      className="flex flex-wrap items-center gap-2 text-sm"
      role="toolbar"
      aria-label="Preview navigation"
      aria-busy={loading}
    >
      {children}
      {loading && (
        <span role="status" className="text-muted-foreground">
          Loading…
        </span>
      )}
    </div>
  )
}

export function StepButtons({
  label,
  previous,
  next,
}: {
  label: string
  previous: (() => void) | null
  next: (() => void) | null
}) {
  return (
    <div className="flex gap-1">
      <Button type="button" variant="outline" size="sm" disabled={!previous} onClick={previous ?? undefined}>
        <ChevronLeftIcon aria-hidden="true" /> Previous {label}
      </Button>
      <Button type="button" variant="outline" size="sm" disabled={!next} onClick={next ?? undefined}>
        Next {label} <ChevronRightIcon aria-hidden="true" />
      </Button>
    </div>
  )
}

// A number field with its own Go button: the page changes only when the form is sent. The
// browser keeps the number within min and max; the server clamps it too.
export function JumpTo({
  label,
  value,
  min,
  max,
  onJump,
}: {
  label: string
  value: number
  min: number
  max: number
  onJump: (value: number) => void
}) {
  const [draft, setDraft] = React.useState(String(value))
  const [shown, setShown] = React.useState(value)
  if (shown !== value) {
    setShown(value)
    setDraft(String(value))
  }

  function submit(event: React.FormEvent) {
    event.preventDefault()
    const number = Number.parseInt(draft, 10)
    if (Number.isFinite(number)) onJump(number)
  }

  return (
    <form onSubmit={submit} className="flex items-center gap-1.5">
      <label className="flex items-center gap-1.5 text-muted-foreground">
        {label}
        <input
          type="number"
          inputMode="numeric"
          min={min}
          max={max}
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          className="h-8 w-20 rounded-md border bg-card px-2 text-sm text-foreground shadow-xs"
        />
      </label>
      <Button type="submit" variant="secondary" size="sm">
        Go
      </Button>
    </form>
  )
}

export function SurahSelect({
  surah,
  surahs,
  onSelect,
}: {
  surah: number
  surahs: PreviewsScriptSurah[]
  onSelect: (surah: number) => void
}) {
  return (
    <label className="flex items-center gap-1.5 text-muted-foreground">
      Surah
      <select className={selectClass} value={surah} onChange={(event) => onSelect(Number(event.target.value))}>
        {surahs.map((entry) => (
          <option key={entry.number} value={entry.number}>
            {entry.number}. {entry.name}
          </option>
        ))}
      </select>
    </label>
  )
}

// The surah picker, the from-ayah jump and the previous and next range of a preview that shows
// a range of ayahs of one surah.
export function AyahRangeToolbar({
  surah,
  surahs,
  from,
  to,
  navigation,
}: {
  surah: PreviewsScriptSurah
  surahs: PreviewsScriptSurah[]
  from: number
  to: number
  navigation: PreviewNavigation
}) {
  const { navigate, loading } = navigation
  const size = to - from + 1
  return (
    <PreviewToolbar loading={loading}>
      <SurahSelect surah={surah.number} surahs={surahs} onSelect={(number) => navigate({ surah: number })} />
      <JumpTo
        label="From ayah"
        value={from}
        min={1}
        max={surah.versesCount}
        onJump={(number) => navigate({ surah: surah.number, from: number })}
      />
      <StepButtons
        label="ayahs"
        previous={from > 1 ? () => navigate({ surah: surah.number, from: Math.max(1, from - size) }) : null}
        next={to < surah.versesCount ? () => navigate({ surah: surah.number, from: to + 1 }) : null}
      />
    </PreviewToolbar>
  )
}

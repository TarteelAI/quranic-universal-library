import { PauseIcon, PlayIcon } from 'lucide-react'
import * as React from 'react'

import { cn } from '@/lib/utils'
import type {
  CatalogSearchResult,
  PreviewsCardLayout,
  PreviewsCardRecitation,
  PreviewsCardScript,
  PreviewsCardText,
} from '@/types/serializers'

import { FontFaces, V4_PALETTE } from './fonts'
import { MushafLine, pageFonts } from './mushaf-page'
import { AyahText } from './script-preview'
import { Html } from './text-preview'

export type CardPreviewKind = NonNullable<CatalogSearchResult['previewKind']>
type CardPreviewData = PreviewsCardLayout | PreviewsCardRecitation | PreviewsCardScript | PreviewsCardText

type State = { status: 'pending' | 'failed' } | { status: 'loaded'; data: CardPreviewData }

// The well's height per kind, the same while loading and once loaded, so cards keep their size.
const HEIGHT: Record<CardPreviewKind, string> = {
  layout: 'h-40',
  recitation: 'h-14',
  script: 'h-14',
  text: 'h-28',
}

// How far outside the viewport a card starts loading its preview.
const ROOT_MARGIN = '200px'

// True from the first time the element comes near the viewport. On the server and before
// hydration it is false, so the server renders the empty well.
function useSeen(ref: React.RefObject<HTMLElement | null>) {
  const [seen, setSeen] = React.useState(false)

  React.useEffect(() => {
    const element = ref.current
    if (!element || seen) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) setSeen(true)
      },
      { rootMargin: ROOT_MARGIN },
    )
    observer.observe(element)
    return () => observer.disconnect()
  }, [ref, seen])

  return seen
}

function LayoutThumbnail({ preview }: { preview: PreviewsCardLayout }) {
  const { page } = preview
  const v4 = page.textFont !== null && page.fontCode === 'v4-tajweed'
  return (
    <div className="flex h-full justify-center overflow-hidden">
      <FontFaces fonts={pageFonts(page)} palette={v4 && page.textFont ? [page.textFont] : []} />
      <div
        dir="rtl"
        className="h-max w-max rounded-sm bg-white px-3 py-2 text-[9px] leading-[1.85] text-black shadow-xs"
        style={{
          fontFamily: page.textFont ? `'${page.textFont.family}'` : undefined,
          fontPalette: v4 ? V4_PALETTE : undefined,
        }}
      >
        {page.lines.map((line) => (
          <MushafLine key={line.number} line={line} fonts={page} />
        ))}
      </div>
    </div>
  )
}

// A play button over the card's link. The <audio> element gets its source only when the
// listener presses play, so nothing is downloaded before that. An ayah-by-ayah recitation has
// one track per ayah, played one after the other.
function RecitationControl({ preview }: { preview: PreviewsCardRecitation }) {
  const audio = React.useRef<HTMLAudioElement>(null)
  const [playing, setPlaying] = React.useState(false)
  const track = React.useRef(0)

  function toggle() {
    const element = audio.current!
    if (playing) {
      element.pause()
    } else {
      if (!element.getAttribute('src')) element.src = preview.tracks[track.current]
      void element.play()
    }
  }

  function next() {
    const element = audio.current!
    track.current = (track.current + 1) % preview.tracks.length
    element.src = preview.tracks[track.current]
    if (track.current === 0) setPlaying(false)
    else void element.play()
  }

  return (
    <div className="flex h-full items-center gap-3">
      <button
        type="button"
        onClick={toggle}
        aria-label={playing ? 'Pause' : `Play Surah ${preview.surah.name}`}
        className="relative z-10 flex size-10 shrink-0 items-center justify-center rounded-full bg-foreground text-background transition-transform hover:scale-105 [&_svg]:size-4 [&_svg]:fill-current"
      >
        {playing ? <PauseIcon /> : <PlayIcon className="ms-0.5" />}
      </button>
      <div className="min-w-0 text-sm">
        <p className="truncate font-medium">Surah {preview.surah.name}</p>
        <p className="text-xs text-muted-foreground">
          {preview.surah.versesCount} ayahs
          {preview.granularity === 'ayah' ? ' · one file per ayah' : preview.highlights && ' · ayah timings'}
        </p>
      </div>
      <audio
        ref={audio}
        preload="none"
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        onEnded={next}
      />
    </div>
  )
}

function ScriptLine({ preview }: { preview: PreviewsCardScript }) {
  const v4 = preview.fontCode === 'v4-tajweed'
  return (
    <>
      <FontFaces fonts={preview.fonts} palette={v4 ? preview.fonts : []} />
      <p
        dir="rtl"
        className={cn(
          'flex h-full items-center justify-center overflow-hidden text-2xl leading-loose whitespace-nowrap',
          preview.rendering === 'html' && 'tajweed',
          preview.rendering === 'image' && '[&_img]:h-7',
        )}
        style={{ fontPalette: v4 ? V4_PALETTE : undefined }}
      >
        <AyahText ayah={preview.ayah} rendering={preview.rendering} />
      </p>
    </>
  )
}

function TextAyah({ preview }: { preview: PreviewsCardText }) {
  const { entry, locale } = preview
  const textClass = 'line-clamp-3 text-sm leading-snug'
  return (
    <div className="flex h-full flex-col gap-1.5 overflow-hidden">
      <p dir="rtl" lang="ar" className="truncate font-arabic text-lg leading-normal">
        {entry.ayahs.map((ayah) => ayah.text).join(' ')}
      </p>
      {preview.granularity === 'word' ? (
        <p lang={locale.code} dir={locale.direction} className={textClass}>
          {entry.words.map((word) => word.text).join(' · ')}
        </p>
      ) : (
        entry.text !== null && <Html html={entry.text} locale={locale} className={textClass} />
      )}
    </div>
  )
}

function Body({ data }: { data: CardPreviewData }) {
  switch (data.kind) {
    case 'layout':
      return <LayoutThumbnail preview={data} />
    case 'recitation':
      return <RecitationControl preview={data} />
    case 'script':
      return <ScriptLine preview={data} />
    case 'text':
      return <TextAyah preview={data} />
  }
}

// What the well shows, for tests: waiting (not near the viewport yet), loading or loaded.
function wellState(state: State, seen: boolean) {
  if (state.status !== 'pending') return state.status
  return seen ? 'loading' : 'waiting'
}

// A resource card's preview (Previews::Card), fetched from `url` once the card comes near the
// viewport, so the catalog's first response, and the fonts and audio of cards never scrolled to,
// cost nothing. Until it arrives the well keeps its loaded size; when it cannot be loaded the
// well goes and the card shows without a preview.
export function CardPreview({ kind, url }: { kind: CardPreviewKind; url: string }) {
  const ref = React.useRef<HTMLDivElement>(null)
  const seen = useSeen(ref)
  const [state, setState] = React.useState<State>({ status: 'pending' })

  React.useEffect(() => {
    if (!seen) return
    const controller = new AbortController()
    fetch(url, { headers: { Accept: 'application/json' }, signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`Preview ${response.status}`)
        return response.json() as Promise<CardPreviewData>
      })
      .then((data) => setState(data.kind === kind ? { status: 'loaded', data } : { status: 'failed' }))
      .catch(() => {
        if (!controller.signal.aborted) setState({ status: 'failed' })
      })
    return () => controller.abort()
  }, [seen, url, kind])

  if (state.status === 'failed') return null

  return (
    <div
      ref={ref}
      className={cn(
        'm-1.5 mb-0 overflow-hidden rounded-lg bg-surface p-4',
        state.status !== 'loaded' && 'animate-pulse',
      )}
      data-testid="card-preview"
      data-kind={kind}
      data-state={wellState(state, seen)}
      aria-busy={state.status !== 'loaded'}
    >
      <div className={HEIGHT[kind]}>{state.status === 'loaded' && <Body data={state.data} />}</div>
    </div>
  )
}

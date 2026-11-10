import { PauseIcon, PlayIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import type { PreviewsRecitation, PreviewsRecitationAyah } from '@/types/serializers'

import { PreviewToolbar, SurahSelect, type PreviewNavigation } from './navigation'

// The ayah being recited `ms` milliseconds into `track`: the one whose times hold that moment.
// Ayahs without times (a recitation without segments) are never recited "now".
export function activeAyah(ayahs: PreviewsRecitationAyah[], track: number, ms: number) {
  return (
    ayahs.find(
      (ayah) => ayah.track === track && ayah.from !== null && ayah.from <= ms && (ayah.to === null || ms < ayah.to),
    ) ?? null
  )
}

function clock(ms: number) {
  const seconds = Math.floor(ms / 1000)
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

// Plays the recitation's tracks one after the other. The <audio> element gets its source only
// when the listener presses play, so nothing is downloaded before that. While it plays, the
// position is read every animation frame, so the highlight moves at the segment boundaries.
function usePlayer(tracks: string[]) {
  const audio = React.useRef<HTMLAudioElement>(null)
  const [track, setTrack] = React.useState(0)
  const [playing, setPlaying] = React.useState(false)
  const [started, setStarted] = React.useState(false)
  const [ms, setMs] = React.useState(0)
  const [duration, setDuration] = React.useState(0)

  React.useEffect(() => {
    if (!playing) return
    let frame = requestAnimationFrame(function tick() {
      if (audio.current) setMs(audio.current.currentTime * 1000)
      frame = requestAnimationFrame(tick)
    })
    return () => cancelAnimationFrame(frame)
  }, [playing])

  function load(index: number) {
    const element = audio.current!
    if (element.getAttribute('src') !== tracks[index]) element.src = tracks[index]
    setTrack(index)
    return element
  }

  function play(index = track, at?: number) {
    const element = load(index)
    if (at !== undefined) element.currentTime = at / 1000
    void element.play()
  }

  const events = {
    onPlay: () => {
      setPlaying(true)
      setStarted(true)
    },
    onPause: () => setPlaying(false),
    onTimeUpdate: (event: React.SyntheticEvent<HTMLAudioElement>) => setMs(event.currentTarget.currentTime * 1000),
    onLoadedMetadata: (event: React.SyntheticEvent<HTMLAudioElement>) =>
      setDuration(event.currentTarget.duration * 1000),
    onEnded: () => {
      if (track + 1 < tracks.length) play(track + 1, 0)
      else setPlaying(false)
    },
  }

  return { audio, events, track, playing, started, ms, duration, play, pause: () => audio.current?.pause() }
}

// A recitation: the surah's audio with its ayahs. Where the ayahs have times, the one being
// recited is highlighted and an ayah can be played from its start.
export function RecitationPlayer({
  preview,
  navigation,
}: {
  preview: PreviewsRecitation
  navigation: PreviewNavigation
}) {
  const { surah, ayahs, tracks, highlights } = preview
  const { audio, events, track, playing, started, ms, duration, play, pause } = usePlayer(tracks)
  const active = highlights && started ? activeAyah(ayahs, track, ms) : null
  const activeRef = React.useRef<HTMLLIElement>(null)

  React.useEffect(() => {
    if (playing) activeRef.current?.scrollIntoView({ block: 'nearest' })
  }, [active?.key, playing])

  function playFrom(ayah: PreviewsRecitationAyah) {
    if (ayah.track !== null) play(ayah.track, ayah.from ?? 0)
  }

  return (
    <div
      className="flex flex-col gap-4"
      data-testid="recitation-preview"
      data-granularity={preview.granularity}
      data-highlights={highlights}
      data-active-ayah={active?.key ?? ''}
    >
      <PreviewToolbar loading={navigation.loading}>
        <SurahSelect
          surah={surah.number}
          surahs={preview.surahs}
          onSelect={(number) => navigation.navigate({ surah: number })}
        />
      </PreviewToolbar>

      <div className="flex items-center gap-3 rounded-xl border bg-card p-3" data-testid="player">
        <audio ref={audio} preload="none" {...events} />
        <Button
          type="button"
          size="icon"
          aria-label={playing ? 'Pause' : 'Play'}
          onClick={() => (playing ? pause() : play())}
        >
          {playing ? <PauseIcon aria-hidden="true" /> : <PlayIcon aria-hidden="true" />}
        </Button>
        <span className="font-mono text-xs text-muted-foreground tabular-nums" data-testid="position">
          {clock(ms)}
          {duration > 0 && ` / ${clock(duration)}`}
        </span>
        <p className="text-sm text-muted-foreground">
          Surah {surah.name}
          {preview.granularity === 'ayah' && `, ayah ${ayahs.find((ayah) => ayah.track === track)?.number ?? 1}`}
        </p>
      </div>
      {!highlights && (
        <p className="text-sm text-muted-foreground">
          This recitation has no segment data for this surah, so the ayah being recited is not highlighted.
        </p>
      )}

      <ol
        dir="rtl"
        lang="ar"
        className="flex max-h-[60vh] flex-col gap-1 overflow-y-auto rounded-xl bg-white p-2 font-arabic text-2xl leading-loose text-black shadow-xs sm:p-4"
        data-testid="recitation-ayahs"
      >
        {ayahs.map((ayah) => {
          const current = ayah.key === active?.key
          return (
            <li
              key={ayah.key}
              ref={current ? activeRef : undefined}
              data-ayah={ayah.key}
              aria-current={current || undefined}
              className={`flex items-start gap-3 rounded-lg px-3 py-1 ${current ? 'bg-amber-100' : ''}`}
            >
              {highlights && ayah.track !== null ? (
                <button
                  type="button"
                  className="mt-2 shrink-0 rounded-md border px-1.5 font-sans text-xs text-neutral-500 hover:bg-neutral-100"
                  aria-label={`Play from ayah ${ayah.key}`}
                  onClick={() => playFrom(ayah)}
                  dir="ltr"
                >
                  {ayah.key}
                </button>
              ) : (
                <span dir="ltr" className="mt-2 shrink-0 font-sans text-xs text-neutral-500">
                  {ayah.key}
                </span>
              )}
              <span>{ayah.text}</span>
            </li>
          )
        })}
      </ol>
    </div>
  )
}

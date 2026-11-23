import { Link, usePage, WhenVisible } from '@inertiajs/react'
import { ArrowRightIcon, GitForkIcon, PauseIcon, PlayIcon, PlusIcon, StarIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { LayoutThumbnail } from '@/components/previews/card-preview'
import { FontFaces } from '@/components/previews/fonts'
import { usePlayer } from '@/components/previews/recitation-player'
import { AyahText } from '@/components/previews/script-preview'
import { Html } from '@/components/previews/text-preview'
import { AppIcon } from '@/components/qul/app-icon'
import { GitHubMark, ResourceIcon } from '@/components/qul/icons'
import { GoalCard, KitCard } from '@/components/qul/start'
import { NavAnchor } from '@/components/qul/nav'
import { ShardRing } from '@/components/qul/shard-ring'
import { ToolCard } from '@/components/qul/tool-card'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/misc'
import { formatStars, REPO, REPO_URL, useGitHubStars } from '@/lib/github'
import { cn } from '@/lib/utils'
import { appsDirectory, catalogResources, detailResources, startSetup } from '@/routes'
import type {
  PreviewsMushafPage,
  PreviewsRecitation,
  PreviewsRecords,
  PreviewsText,
  SiteCategoryCount,
  SiteHomeShow,
  SiteSample,
  SiteSampleCards,
} from '@/types/serializers'

// The shard ring draws on this colour (renderer.js BACKGROUND, as displayed), so the panel and
// the canvas meet without a seam.
const RING_BG = '#030304'

const number = (count: number) => count.toLocaleString('en')

// The home page (/): the hero with the shard ring, the catalog counts and the contributors, the apps built with
// QUL, the guided setup's goals, the library (a card per category, with a look at its data), the
// starter kits and the open source band with three contribution tools. From
// the v8 design (ds/src/app/pages/home.tsx); the MCP server section is left out. With the
// `start` group off there are no goals or kits, and the hero and closing buttons lead to the
// catalog and the docs.
export default function HomePage(props: SiteHomeShow) {
  return (
    <SiteShell>
      <Hero {...props} />
      <Apps {...props} />
      {props.goals.length > 0 && <Goals goals={props.goals} />}
      <Library {...props} />
      {props.kits.length > 0 && <Kits kits={props.kits} />}
      <OpenSource {...props} />
      <Closing catalogPages={props.catalogPages} startPages={props.startPages} />
    </SiteShell>
  )
}

function catalogLink(catalogPages: boolean) {
  return { href: catalogResources.index().url, inertia: catalogPages }
}

// The hero's and the closing banner's buttons: the guided setup first while it is served.
function CallsToAction({ catalogPages, startPages }: { catalogPages: boolean; startPages: boolean }) {
  if (startPages)
    return (
      <>
        <Button size="lg" variant="brand" asChild>
          <Link href={startSetup.show().url}>
            Start building <ArrowRightIcon />
          </Link>
        </Button>
        <Button size="lg" variant="outline" asChild>
          <NavAnchor link={catalogLink(catalogPages)}>Browse the library</NavAnchor>
        </Button>
      </>
    )

  return (
    <Button size="lg" variant="brand" asChild>
      <NavAnchor link={catalogLink(catalogPages)}>
        Browse the library <ArrowRightIcon />
      </NavAnchor>
    </Button>
  )
}

/* ---------------- hero ---------------- */

function Hero({ resources, languages, contributors, catalogPages, startPages }: SiteHomeShow) {
  return (
    <section className="pt-4 sm:pt-6">
      <Container>
        {/* Below lg the text overlays the lower part of the ring, so the hero stays short. */}
        <div
          className="dark relative grid overflow-hidden rounded-3xl text-foreground lg:min-h-[620px] lg:grid-cols-[1.05fr_1fr]"
          style={{ backgroundColor: RING_BG }}
        >
          <ShardRing className="absolute inset-x-0 top-0 h-[340px] sm:h-[460px] lg:relative lg:order-2 lg:h-auto" />
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-x-0 top-0 h-[340px] sm:h-[460px] lg:hidden"
            style={{ background: `linear-gradient(to bottom, transparent 15%, ${RING_BG} 75%)` }}
          />
          <div className="relative flex flex-col justify-center gap-4 px-5 pt-44 pb-8 sm:gap-6 sm:px-12 sm:pt-72 sm:pb-14 lg:order-1 lg:py-20 lg:ps-14 lg:pe-0">
            <p className="text-sm font-medium text-brand">Quranic Universal Library</p>
            <h1 className="headline -mt-1 text-[clamp(2rem,4.6vw,4.25rem)] text-balance text-white">
              Verified data for builders impacting the Ummah.
            </h1>
            <p className="max-w-xl text-base text-pretty text-white/70 sm:text-lg">
              QUL is the open library behind Quran apps everywhere: translations, tafsir, recitations with word timing,
              mushaf layouts, fonts and morphology. Scholars and engineers check every resource, so you can ship it with
              confidence.
            </p>
            <div className="flex flex-wrap items-center gap-3">
              <CallsToAction catalogPages={catalogPages} startPages={startPages} />
              {!startPages && (
                <Button size="lg" variant="outline" asChild>
                  <a href="/docs/getting-started">Read the docs</a>
                </Button>
              )}
              <HeroStar />
            </div>
            <dl className="mt-2 grid grid-cols-3 gap-4 border-t border-white/10 pt-5 sm:flex sm:gap-x-14">
              <Stat value={resources} label="resources" />
              <Stat value={languages} label="languages" />
              <Stat value={contributors} label="contributors" />
            </dl>
          </div>
        </div>
      </Container>
    </section>
  )
}

function Stat({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col-reverse">
      <dt className="mt-1 text-sm text-muted-foreground">{label}</dt>
      <dd className="headline text-3xl text-white tabular-nums">{number(value)}</dd>
    </div>
  )
}

function HeroStar() {
  const stars = useGitHubStars()
  return (
    <a
      href={REPO_URL}
      target="_blank"
      rel="noreferrer"
      className="inline-flex h-10 items-center gap-2 rounded-md px-3 text-sm font-medium text-white/80 transition-colors outline-none hover:bg-white/5 hover:text-white focus-visible:ring-[3px] focus-visible:ring-ring/50"
    >
      <GitHubMark />
      Star on GitHub
      <span className="inline-flex items-center gap-1 font-mono text-xs text-white/60 tabular-nums">
        <StarIcon className="size-3 fill-current" />
        {formatStars(stars)}
      </span>
    </a>
  )
}

/* ---------------- apps built with QUL ---------------- */

function Apps({ showcase, appsCount, appsPage }: SiteHomeShow) {
  return (
    <section className="py-12 sm:py-16">
      <Container className="flex flex-col gap-8 lg:flex-row lg:items-center lg:gap-14">
        <div className="flex shrink-0 flex-col gap-3 lg:w-80">
          <h2 className="headline text-2xl text-balance sm:text-3xl">
            Trusted by the leading Quran applications and communities worldwide.
          </h2>
          <p className="text-sm text-pretty text-muted-foreground">
            {Math.floor(appsCount / 5) * 5}+ readers, hifz and study apps and developer libraries credit QUL for their
            text, layouts, fonts, audio timing and tafsir.
          </p>
          {/* The apps directory, and its submission form, exist only while the `apps` group is on. */}
          {appsPage && (
            <div className="mt-1 flex flex-wrap gap-2">
              <Button variant="outline" size="sm" asChild>
                <NavAnchor link={{ href: appsDirectory().url, inertia: true }}>
                  See the apps <ArrowRightIcon />
                </NavAnchor>
              </Button>
              <Button variant="ghost" size="sm" asChild>
                <NavAnchor link={{ href: appsDirectory({ query: { submit: 1 } }).url, inertia: true }}>
                  <PlusIcon /> Submit your app
                </NavAnchor>
              </Button>
            </div>
          )}
        </div>
        <ul className="grid min-w-0 flex-1 grid-cols-2 gap-x-6 gap-y-5 sm:grid-cols-3 xl:grid-cols-4">
          {showcase.map((app) => (
            <li key={app.id} className="min-w-0">
              <a href={app.url} target="_blank" rel="noreferrer" className="group flex items-center gap-3">
                <AppIcon app={app} size="sm" />
                <span className="flex min-w-0 flex-col">
                  <span className="text-sm leading-tight font-medium group-hover:underline">{app.name}</span>
                  <span className="truncate text-xs text-muted-foreground">{app.kind}</span>
                </span>
              </a>
            </li>
          ))}
        </ul>
      </Container>
    </section>
  )
}

/* ---------------- goals ---------------- */

function Goals({ goals }: { goals: SiteHomeShow['goals'] }) {
  return (
    <Section>
      <Container>
        <SectionTitle
          title="What are you building?"
          text="Pick a goal, answer four more questions, and see the resources your app needs."
        />
        <ul className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {goals.map((goal) => (
            <li key={goal.key}>
              <GoalCard goal={goal} href={startSetup.show({ query: { goal: goal.key } }).url} />
            </li>
          ))}
        </ul>
      </Container>
    </Section>
  )
}

/* ---------------- the library: a card per category, with a look at its data ---------------- */

type SampleType = SiteSample['type']

// The prop that holds the preview of each sampled type (Site::HomeShowResource::PREVIEWS). The
// first response carries none of them: each loads once its card comes near the screen.
const PREVIEW_PROPS = {
  recitation: 'recitationPreview',
  'mushaf-layout': 'mushafLayoutPreview',
  'quran-script': 'quranScriptPreview',
  translation: 'translationPreview',
  tafsir: 'tafsirPreview',
  morphology: 'morphologyPreview',
  'ayah-topics': 'ayahTopicsPreview',
  'quran-metadata': 'quranMetadataPreview',
} as const satisfies Record<SampleType, keyof SiteHomeShow>

// The height of each sample's well once its preview is in (the layout's page is under its text
// below sm, beside it from sm up). The well has it from the start, so the section does not grow
// as the previews load. The narrow cards' wells are as high as an empty one (EmptyWell). The words
// of the morphology sample take two lines, but one on the full-width card at md.
const WELL_HEIGHT: Record<SampleType, string> = {
  recitation: 'min-h-42',
  'mushaf-layout': 'min-h-71 sm:min-h-53',
  translation: 'min-h-65 sm:min-h-52 lg:min-h-58',
  morphology: 'min-h-67 md:min-h-57 lg:min-h-67',
  'ayah-topics': 'min-h-32 md:min-h-40',
  'quran-script': 'min-h-40',
  tafsir: 'min-h-40',
  'quran-metadata': 'min-h-40',
}

// The sampled types whose card is one column wide, the others two. Topics names no sample.
const NARROW: SampleType[] = ['quran-script', 'tafsir', 'ayah-topics', 'quran-metadata']

function Library(props: SiteHomeShow) {
  const { categories, resources, samples, catalogPages } = props
  return (
    <Section>
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-4">
          <SectionTitle
            title="The whole Quran, as data you can ship"
            text="Every resource is reviewed before it's published and versioned after, so a fix reaches every app that uses it."
          />
          <Button variant="outline" asChild>
            <NavAnchor link={catalogLink(catalogPages)}>
              All {number(resources)} resources <ArrowRightIcon />
            </NavAnchor>
          </Button>
        </div>
        {/* A bento grid in taxonomy order: the interactive cards take two columns, so each row
            of four columns is full; `dense` lets a one-column card fill a gap at two columns.
            A card is two rows of the grid (its heading, its well), so the wells of a row start
            on one line whatever the length of the headings. */}
        <ul className="mt-10 grid gap-3 md:grid-flow-dense md:grid-cols-2 lg:grid-cols-4">
          {categories.map((category) => {
            const sample = samples.find((candidate) => candidate.category === category.key)
            return (
              <li
                key={category.key}
                className={cn(
                  'row-span-2 grid grid-cols-1 grid-rows-subgrid',
                  sample && !NARROW.includes(sample.type) && 'md:col-span-2',
                )}
              >
                <CategoryCard category={category} catalogPages={catalogPages}>
                  {sample ? (
                    <SampleWell
                      sample={sample}
                      preview={props[PREVIEW_PROPS[sample.type]]}
                      catalogPages={catalogPages}
                    />
                  ) : (
                    <EmptyWell />
                  )}
                </CategoryCard>
              </li>
            )
          })}
        </ul>
      </Container>
    </Section>
  )
}

// A category: its icon, label, hint and count over a look at its data. The label's link covers
// the card; the controls and links in the well sit above it.
function CategoryCard({
  category,
  catalogPages,
  children,
}: {
  category: SiteCategoryCount
  catalogPages: boolean
  children: React.ReactNode
}) {
  return (
    <article
      className="group relative row-span-full grid grid-cols-1 grid-rows-subgrid gap-y-5 rounded-2xl bg-card p-4 shadow-xs transition-shadow hover:shadow-md sm:p-5"
      data-testid="library-card"
      data-category={category.key}
    >
      <div className="flex min-w-0 items-start gap-3">
        <ResourceIcon category={category.key} size="md" />
        <div className="flex min-w-0 flex-1 flex-col">
          <h3 className="font-medium">
            <NavAnchor
              link={{ href: catalogResources.index({ query: { category: category.key } }).url, inertia: catalogPages }}
              className="outline-none after:absolute after:inset-0 after:rounded-2xl focus-visible:after:ring-[3px] focus-visible:after:ring-ring/50"
            >
              {category.label}
            </NavAnchor>
          </h3>
          <p className="text-sm text-pretty text-muted-foreground">{category.hint}</p>
        </div>
        <span className="flex items-center gap-1.5 pt-0.5 font-mono text-xs text-muted-foreground tabular-nums">
          {number(category.count)}
          <ArrowRightIcon className="size-3.5 transition-transform group-hover:translate-x-0.5 group-hover:text-foreground" />
        </span>
      </div>
      {children}
    </article>
  )
}

const WELL = 'flex flex-1 flex-col rounded-xl bg-surface p-4'

// A sampled type's well: a part of its sample's preview, loaded once the card is near the screen.
// The preview names its sample under its own title, with a link to the sample's page, where the
// whole preview is.
function SampleWell({
  sample,
  preview,
  catalogPages,
}: {
  sample: SiteSample
  preview: SiteHomeShow[(typeof PREVIEW_PROPS)[SampleType]]
  catalogPages: boolean
}) {
  // Inline content: each preview sets it as a line of its own.
  const source = sample.type !== 'ayah-topics' && (
    <>
      From{' '}
      <NavAnchor
        link={{ href: detailResources({ type: sample.type, id: sample.toParam }).url, inertia: catalogPages }}
        className="relative z-10 text-foreground underline-offset-4 hover:underline"
      >
        {sample.name}
      </NavAnchor>
    </>
  )
  return (
    <div className={cn(WELL, 'row-[2/-1] min-w-0', WELL_HEIGHT[sample.type])}>
      <WhenVisible data={PREVIEW_PROPS[sample.type]} buffer={400} fallback={<WellSkeleton />}>
        <div className="flex flex-1 flex-col" data-testid="sample-preview" data-type={sample.type}>
          <SamplePreview type={sample.type} preview={preview} source={source} />
        </div>
      </WhenVisible>
    </div>
  )
}

// The lines of a preview that is still loading. The well is the surface colour, which `muted`
// does not show on, so the lines take the border colour.
function WellSkeleton() {
  return (
    <div className="flex flex-col gap-3" aria-hidden="true">
      {['w-2/5', 'w-4/5', 'w-3/5'].map((width) => (
        <Skeleton key={width} className={cn('h-4 rounded-md bg-border', width)} />
      ))}
    </div>
  )
}

function SamplePreview({
  type,
  preview,
  source,
}: {
  type: SampleType
  preview: SiteHomeShow[(typeof PREVIEW_PROPS)[SampleType]]
  source?: React.ReactNode
}) {
  switch (preview?.kind) {
    case 'recitation':
      return <AyahPlayer preview={preview} source={source} />
    case 'layout':
      return <PageThumbnail page={preview.page} source={source} />
    case 'cards':
      return type === 'quran-script' ? <ScriptLines preview={preview} /> : <AyahTranslations preview={preview} />
    case 'text':
      return <TafsirExcerpt preview={preview} source={source} />
    case 'records':
      if (type === 'ayah-topics') return <TopicAyahs preview={preview} />
      if (type === 'quran-metadata') return <SurahRows preview={preview} />
      return <WordParts preview={preview} source={source} />
    default:
      return <p className="m-auto text-sm text-muted-foreground">No preview of this resource.</p>
  }
}

// The surah's audio, one ayah on screen at a time: the one being recited, where the ayahs have
// times. Each ayah is a step of the bar, as long as its recitation, and plays from its start.
function AyahPlayer({ preview, source }: { preview: PreviewsRecitation; source?: React.ReactNode }) {
  const { surah, ayahs, tracks, highlights } = preview
  const { audio, events, track, playing, started, ms, duration, play, pause } = usePlayer(tracks)
  const timed = highlights ? ayahs.filter((ayah) => ayah.track !== null && ayah.from !== null) : []
  // A step runs from its ayah's start to the next ayah's start, so the pause between two ayahs
  // is part of the first: the bar keeps moving, and the ayah stays on screen until the next one
  // begins (no ayah is recited in the pause, and the card used to fall back to the first ayah).
  const steps = timed.map((ayah, index) => {
    const next = timed[index + 1]
    return { ayah, from: ayah.from!, to: next?.track === ayah.track ? next.from! : (ayah.to ?? duration) }
  })
  const reached = started
    ? steps.filter((step) => step.ayah.track! < track || (step.ayah.track === track && step.from <= ms))
    : []
  const current = reached.at(-1)
  const shown = current?.ayah ?? ayahs[0]
  // The ayah that was on screen before, fading out under the new one.
  const [onScreen, setOnScreen] = React.useState(shown)
  const [leaving, setLeaving] = React.useState<typeof shown | null>(null)
  if (shown?.key !== onScreen?.key) {
    setLeaving(onScreen)
    setOnScreen(shown)
  }

  return (
    <div className="flex flex-1 flex-col gap-4" data-active-ayah={current?.ayah.key ?? ''}>
      <audio ref={audio} preload="none" {...events} />
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => (playing ? pause() : play())}
          aria-label={playing ? 'Pause' : `Play Surah ${surah.name}`}
          className="relative z-10 flex size-10 shrink-0 items-center justify-center rounded-full bg-foreground text-background transition-transform outline-none hover:scale-105 focus-visible:ring-[3px] focus-visible:ring-ring/50 [&_svg]:size-4 [&_svg]:fill-current"
        >
          {playing ? <PauseIcon /> : <PlayIcon className="ms-0.5" />}
        </button>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium">Surah {surah.name}</p>
          {source && <p className="truncate text-sm text-muted-foreground">{source}</p>}
        </div>
        <span className="font-mono text-xs text-muted-foreground tabular-nums">{shown?.key}</span>
      </div>
      {shown && (
        // Both ayahs share one grid cell: the old one fades out, then the new one fades in. They
        // barely overlap, since two Arabic lines drawn over each other are unreadable.
        <div dir="rtl" lang="ar" className="my-auto grid text-center font-arabic text-2xl leading-loose text-balance">
          {leaving && (
            <p
              key={`leaving-${leaving.key}`}
              aria-hidden="true"
              onAnimationEnd={() => setLeaving(null)}
              className="animate-out fill-mode-forwards duration-150 ease-in fade-out [grid-area:1/1] motion-reduce:hidden"
            >
              {leaving.text}
            </p>
          )}
          <p
            key={shown.key}
            className="animate-in fill-mode-backwards delay-150 duration-300 ease-out fade-in slide-in-from-bottom-1 [grid-area:1/1] motion-reduce:animate-none"
          >
            {shown.text}
          </p>
        </div>
      )}
      {steps.length > 0 ? (
        <div dir="rtl" className="flex gap-1">
          {steps.map(({ ayah, from, to }) => {
            // A step of an earlier file is done; one of this file fills with the position, once
            // its end is known (an ayah's own file has no end until its length loads).
            const fill = ayah.track === track && to > from ? (ms - from) / (to - from) : 0
            const progress = ayah.track! < track ? 100 : Math.min(Math.max(fill, 0), 1) * 100
            return (
              <button
                key={ayah.key}
                type="button"
                aria-label={`Play from ayah ${ayah.key}`}
                onClick={() => play(ayah.track!, from)}
                className="group/ayah relative z-10 h-4 min-w-2 rounded-full outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50"
                style={{ flexGrow: Math.max(to - from, 1) }}
              >
                <span className="absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 overflow-hidden rounded-full bg-border group-hover/ayah:bg-muted-foreground/40">
                  <span className="absolute inset-y-0 start-0 bg-cat-audio" style={{ width: `${progress}%` }} />
                </span>
              </button>
            )
          })}
        </div>
      ) : (
        <p className="text-xs text-muted-foreground">
          {preview.granularity === 'ayah' ? 'One file per ayah' : 'One file for the surah'}
        </p>
      )}
    </div>
  )
}

// A layout's first page, as the catalog's layout cards show it, beside its page count.
function PageThumbnail({ page, source }: { page: PreviewsMushafPage; source?: React.ReactNode }) {
  return (
    <div className="flex flex-1 flex-col items-center gap-4 sm:flex-row sm:gap-6">
      <div className="flex min-w-0 flex-col gap-1 self-start sm:flex-1 sm:self-center">
        <p className="headline text-3xl tabular-nums">{number(page.pagesCount)}</p>
        <p className="text-sm text-pretty text-muted-foreground">pages, line for line as printed</p>
        {source && <p className="mt-2 truncate text-sm text-muted-foreground">{source}</p>}
      </div>
      <LayoutThumbnail preview={{ kind: 'layout', page }} className="text-[11px]" />
    </div>
  )
}

// How long each translation stays on screen while the translation card goes through them.
const TRANSLATION_MS = 4000
const REDUCED_MOTION = '(prefers-reduced-motion: reduce)'

// Whether the reader asks for less motion; false on the server and without matchMedia (jsdom).
function useReducedMotion() {
  return React.useSyncExternalStore(
    (onChange) => {
      const query = window.matchMedia?.(REDUCED_MOTION)
      query?.addEventListener('change', onChange)
      return () => query?.removeEventListener('change', onChange)
    },
    () => window.matchMedia?.(REDUCED_MOTION).matches ?? false,
    () => false,
  )
}

// Whether the pointer or the focus is in the card around `ref`. The card's link covers the well,
// so the card, not the well, is what the pointer is over.
function useHeld(ref: React.RefObject<HTMLElement | null>) {
  const [hovered, setHovered] = React.useState(false)
  const [focused, setFocused] = React.useState(false)
  React.useEffect(() => {
    const card = ref.current?.closest('article')
    if (!card) return
    const enter = () => setHovered(true)
    const leave = () => setHovered(false)
    const focusIn = () => setFocused(true)
    const focusOut = (event: FocusEvent) => setFocused(card.contains(event.relatedTarget as Node | null))
    card.addEventListener('pointerenter', enter)
    card.addEventListener('pointerleave', leave)
    card.addEventListener('focusin', focusIn)
    card.addEventListener('focusout', focusOut)
    return () => {
      card.removeEventListener('pointerenter', enter)
      card.removeEventListener('pointerleave', leave)
      card.removeEventListener('focusin', focusIn)
      card.removeEventListener('focusout', focusOut)
    }
  }, [ref])
  return hovered || focused
}

// Ayah 1:2 in the sample and in the first translations of other languages, one at a time. The
// card goes through them while the pointer and the focus are elsewhere, and stops for good once
// a language is picked, or never starts when the reader asks for less motion. The translations
// share one grid cell, so the longest sets the height and the card keeps its size as they change.
function AyahTranslations({ preview }: { preview: SiteSampleCards }) {
  const { catalogPages } = usePage<SiteHomeShow>().props
  const translations = preview.cards.flatMap((card) =>
    card.preview.kind === 'text' ? [{ ...card, preview: card.preview }] : [],
  )
  const ref = React.useRef<HTMLDivElement>(null)
  const [index, setIndex] = React.useState(0)
  const [picked, setPicked] = React.useState(false)
  const held = useHeld(ref)
  const still = useReducedMotion()
  const moving = !held && !picked && !still && translations.length > 1

  React.useEffect(() => {
    if (!moving) return
    const timer = window.setTimeout(() => setIndex((at) => (at + 1) % translations.length), TRANSLATION_MS)
    return () => window.clearTimeout(timer)
  }, [moving, index, translations.length])

  const shown = translations[index]
  if (!shown) return null
  const { entry } = shown.preview

  return (
    <div ref={ref} className="flex flex-1 flex-col gap-3" data-language={shown.preview.locale.code}>
      <div className="min-w-0">
        <p className="truncate text-sm font-medium">Ayah {entry.key}</p>
        <p className="truncate text-sm text-muted-foreground">
          From{' '}
          <NavAnchor
            link={{ href: detailResources({ type: 'translation', id: shown.toParam }).url, inertia: catalogPages }}
            className="relative z-10 text-foreground underline-offset-4 hover:underline"
          >
            {shown.name}
          </NavAnchor>
        </p>
      </div>
      <p dir="rtl" lang="ar" className="font-arabic text-2xl leading-loose text-balance">
        {entry.ayahs.map((ayah) => ayah.text).join(' ')}
      </p>
      <div className="grid">
        {translations.map((translation, at) => (
          <div
            key={translation.toParam}
            aria-hidden={at !== index}
            className={cn(
              'transition-[opacity,visibility] duration-500 [grid-area:1/1] motion-reduce:transition-none',
              at === index ? 'visible opacity-100' : 'invisible opacity-0',
            )}
          >
            <Html
              html={translation.preview.entry.text ?? ''}
              locale={translation.preview.locale}
              className="text-pretty [&_sup]:hidden"
            />
          </div>
        ))}
      </div>
      <div role="group" aria-label="Languages" className="mt-auto flex flex-wrap gap-1.5 pt-1">
        {translations.map((translation, at) => (
          <button
            key={translation.toParam}
            type="button"
            aria-pressed={at === index}
            onClick={() => {
              setIndex(at)
              setPicked(true)
            }}
            className={cn(
              'relative z-10 rounded-full border px-2.5 py-0.5 text-xs transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
              at === index
                ? 'border-cat-translation bg-card text-foreground'
                : 'bg-card text-muted-foreground hover:text-foreground',
            )}
          >
            {translation.label}
          </button>
        ))}
      </div>
    </div>
  )
}

// The words of the start of the Quran; the chosen one is shown beside its data (a root, a lemma
// or a grammar term, as the sample has it).
function WordParts({ preview, source }: { preview: PreviewsRecords; source?: React.ReactNode }) {
  const words = preview.records.filter((record) => record.arabic)
  const [index, setIndex] = React.useState(0)
  const word = words[index]
  if (!word) return null
  const data = word.tags.length > 0 ? word.tags : [word.text ?? '']

  return (
    <div className="flex flex-1 flex-col gap-4">
      <div className="min-w-0">
        <p className="truncate text-sm font-medium">The first words of the Quran</p>
        {source && <p className="truncate text-sm text-muted-foreground">{source}</p>}
      </div>
      <div dir="rtl" lang="ar" className="flex flex-wrap gap-1">
        {words.map((record, at) => (
          <button
            key={record.key}
            type="button"
            aria-pressed={at === index}
            aria-label={`Word ${record.label}`}
            onClick={() => setIndex(at)}
            className={cn(
              'relative z-10 rounded-md px-2 font-arabic text-lg leading-loose transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
              at === index ? 'bg-card text-cat-linguistics shadow-xs' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            {record.arabic}
          </button>
        ))}
      </div>
      <div className="mt-auto flex items-center justify-between gap-4 rounded-lg border bg-card px-4 py-3">
        <div className="flex min-w-0 flex-col">
          <span className="font-mono text-xs text-muted-foreground">{word.label}</span>
          <span dir="rtl" lang="ar" className="font-arabic text-3xl leading-normal">
            {word.arabic}
          </span>
        </div>
        <div dir="rtl" lang="ar" className="flex flex-wrap justify-end gap-1.5">
          {data
            .flatMap((value) => value.split(' '))
            .map((part, at) => (
              <span
                key={at}
                className="flex h-11 min-w-11 items-center justify-center rounded-lg bg-surface px-2 font-arabic text-2xl text-cat-linguistics"
              >
                {part}
              </span>
            ))}
        </div>
      </div>
    </div>
  )
}

const chip = 'rounded-md border bg-card px-2 py-0.5 text-xs text-muted-foreground'

// The first topic of the sample over the first ayahs it is about.
function TopicAyahs({ preview }: { preview: PreviewsRecords }) {
  const topic = preview.records[0]
  if (!topic) return null
  // The tags are ayah keys, then a count of the rest ("148 more ayahs").
  // Three fit on one line in the narrow card.
  const ayahs = topic.tags.filter((tag) => /^\d+:\d+$/.test(tag)).slice(0, 3)

  return (
    <div className="my-auto flex flex-col items-center gap-2">
      <span className="rounded-full bg-card px-3 py-1 text-sm font-medium text-cat-topics shadow-xs">
        {topic.label}
      </span>
      <span className="h-3 w-px bg-border" />
      <ul aria-label={`Ayahs about ${topic.label}`} className="flex flex-wrap justify-center gap-1.5 font-mono">
        {ayahs.map((key) => (
          <li key={key} className={chip}>
            {key}
          </li>
        ))}
      </ul>
    </div>
  )
}

// Ayah 1:2 in a Madani and an IndoPak script, each in its own font, and a surah's name in a
// surah name font, as the catalog's script and font cards show them. The fonts load with the
// preview, once the card is near the screen.
function ScriptLines({ preview }: { preview: SiteSampleCards }) {
  const scripts = preview.cards.flatMap((card) =>
    card.preview.kind === 'script' || card.preview.kind === 'font' ? [{ ...card, preview: card.preview }] : [],
  )
  const fonts = scripts
    .flatMap((script) => (script.preview.kind === 'font' ? [script.preview.font] : script.preview.fonts))
    .filter((font, at, all) => all.findIndex((other) => other.family === font.family) === at)

  return (
    // A size container: in a narrow card each label is over its line, and the lines' type
    // shrinks to fit (an ayah is about 8.6 times as wide as its type size).
    <div className="my-auto flex flex-col gap-1 @container">
      <FontFaces fonts={fonts} />
      {scripts.map((script) => (
        <div
          key={script.toParam}
          className="flex flex-col @[14rem]:h-10 @[14rem]:flex-row @[14rem]:items-center @[14rem]:gap-3"
          data-script={script.label}
        >
          <span className="text-[11px] leading-3.5 text-muted-foreground @[14rem]:w-14 @[14rem]:shrink-0 @[14rem]:text-xs">
            {script.label}
          </span>
          <p
            dir="rtl"
            lang="ar"
            className={cn(
              'min-w-0 flex-1 overflow-x-clip text-[min(22px,calc(100cqw/8.6))] leading-[1.4] whitespace-nowrap @[14rem]:text-[min(22px,calc((100cqw-68px)/8.6))] @[14rem]:leading-[2]',
              script.preview.kind === 'script' && script.preview.rendering === 'html' && 'tajweed',
            )}
            style={script.preview.kind === 'font' ? { fontFamily: `'${script.preview.font.family}'` } : undefined}
          >
            {script.preview.kind === 'font' ? (
              script.preview.text
            ) : (
              <AyahText ayah={script.preview.ayah} rendering={script.preview.rendering} />
            )}
          </p>
        </div>
      ))}
    </div>
  )
}

// The start of the sample's entry for ayah 1:1, under the ayah: as much as the well has room
// for, fading out at its foot.
function TafsirExcerpt({ preview, source }: { preview: PreviewsText; source?: React.ReactNode }) {
  const entry = preview.entries[0]
  if (!entry?.text) return <p className="m-auto text-sm text-muted-foreground">No entry for this ayah.</p>

  return (
    <div className="flex flex-1 flex-col gap-2" data-entry={entry.key}>
      <div className="min-w-0">
        <div className="flex items-center gap-3">
          <span className="font-mono text-xs text-muted-foreground tabular-nums">{entry.key}</span>
          <p dir="rtl" lang="ar" className="min-w-0 flex-1 truncate font-arabic text-lg leading-normal">
            {entry.ayahs.map((ayah) => ayah.text).join(' ')}
          </p>
        </div>
        {source && <p className="truncate text-sm text-muted-foreground">{source}</p>}
      </div>
      {/* Out of the flow, so the length of the entry never sets the height of the well. */}
      <div className="relative min-h-16 flex-1">
        <Html
          html={entry.text}
          locale={preview.locale}
          className="absolute inset-0 overflow-hidden text-sm leading-relaxed text-pretty mask-b-from-50% [&_:is(h1,h2,h3,h4,h5,h6)]:font-medium [&_[lang=ar]]:font-arabic [&_sup]:hidden"
        />
      </div>
    </div>
  )
}

// The first three surahs of the sample with their names, ayahs and where each was revealed.
function SurahRows({ preview }: { preview: PreviewsRecords }) {
  return (
    <ul className="my-auto flex flex-col gap-2">
      {preview.records.slice(0, 3).map((surah) => (
        <li key={surah.key} className="flex min-w-0 flex-col">
          <div className="flex items-center justify-between gap-3">
            <span className="truncate text-sm font-medium">{surah.label}</span>
            {surah.arabic && (
              <span dir="rtl" lang="ar" className="shrink-0 font-arabic leading-5">
                {surah.arabic}
              </span>
            )}
          </div>
          <span className="text-xs text-pretty text-muted-foreground">{surah.text}</span>
        </li>
      ))}
    </ul>
  )
}

// The well of a category with no sample to show (none of its types has a published resource).
function EmptyWell() {
  return <div className={cn(WELL, 'min-h-32 md:min-h-40')} aria-hidden="true" />
}

/* ---------------- starter kits ---------------- */

function Kits({ kits }: { kits: SiteHomeShow['kits'] }) {
  return (
    <Section>
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-4">
          <SectionTitle
            title="Start from a kit"
            text="Curated sets of resources that work together, with the reason for each pick."
          />
          <Button variant="outline" asChild>
            <Link href="/kits">
              All kits <ArrowRightIcon />
            </Link>
          </Button>
        </div>
        <ul className="mt-10 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {kits.map((kit) => (
            <li key={kit.key}>
              <KitCard kit={kit} />
            </li>
          ))}
        </ul>
      </Container>
    </Section>
  )
}

/* ---------------- open source ---------------- */

function OpenSource({ tools, contentPages }: SiteHomeShow) {
  const stars = useGitHubStars()
  return (
    <Section>
      <Container className="grid gap-12 lg:grid-cols-[1fr_1.2fr] lg:gap-16">
        <div className="flex min-w-0 flex-col items-start gap-6">
          <SectionTitle
            title="Open source, checked in public"
            text="QUL's code and data live on GitHub. Volunteers proofread every resource, and each fix ships to every app built on QUL. Star the repo to follow releases, or pick a tool and review a few ayahs."
          />
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="group flex w-full max-w-md items-center gap-4 rounded-2xl bg-card p-4 shadow-xs transition-shadow outline-none hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50"
          >
            <span className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-foreground text-background">
              <GitHubMark className="size-6" />
            </span>
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate font-medium">{REPO}</span>
              <span className="text-sm text-muted-foreground">
                <span className="tabular-nums">{number(stars)}</span> stars on GitHub
              </span>
            </span>
            <span className="inline-flex h-9 shrink-0 items-center gap-1.5 rounded-md bg-brand px-3 text-sm font-medium text-brand-foreground transition-colors group-hover:bg-brand/85">
              <StarIcon className="size-4" /> Star
            </span>
          </a>
          <div className="flex flex-wrap gap-3">
            <Button variant="outline" asChild>
              <a href={`${REPO_URL}/fork`} target="_blank" rel="noreferrer">
                <GitForkIcon /> Fork the repo
              </a>
            </Button>
            <Button variant="ghost" asChild>
              <NavAnchor link={{ href: '/tools', inertia: contentPages }}>See all tools</NavAnchor>
            </Button>
          </div>
        </div>
        <ul aria-label="Contribution tools" className="flex min-w-0 flex-col gap-2 lg:pt-2">
          {tools.map((tool) => (
            <li key={tool.href}>
              <ToolCard tool={tool} />
            </li>
          ))}
        </ul>
      </Container>
    </Section>
  )
}

/* ---------------- closing ---------------- */

function Closing({ catalogPages, startPages }: { catalogPages: boolean; startPages: boolean }) {
  return (
    <Section className="pb-0 sm:pb-0">
      <Container>
        <div className="flex flex-col items-start gap-6 rounded-3xl bg-brand-subtle px-6 py-12 sm:items-center sm:px-12 sm:py-16 sm:text-center">
          <h2 className="headline max-w-2xl text-3xl text-balance sm:text-5xl">
            Build on Quran data the world can trust.
          </h2>
          <p className="max-w-xl text-pretty text-muted-foreground">
            Free to download, free to query, and open for anyone to improve.
          </p>
          <div className="flex flex-wrap gap-3">
            <CallsToAction catalogPages={catalogPages} startPages={startPages} />
          </div>
        </div>
      </Container>
    </Section>
  )
}

/** Every section after the apps band: the same hairline divider and the same vertical rhythm. */
function Section({ className, children }: { className?: string; children: React.ReactNode }) {
  return <section className={cn('border-t py-16 sm:py-24', className)}>{children}</section>
}

function SectionTitle({ title, text }: { title: string; text: string }) {
  return (
    <div className="flex max-w-2xl flex-col gap-2">
      <h2 className="headline text-3xl sm:text-4xl">{title}</h2>
      <p className="mt-1 text-pretty text-muted-foreground">{text}</p>
    </div>
  )
}

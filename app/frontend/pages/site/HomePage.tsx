import { Link, WhenVisible } from '@inertiajs/react'
import {
  ArrowRightIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  GitForkIcon,
  PauseIcon,
  PlayIcon,
  PlusIcon,
  StarIcon,
} from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { LayoutThumbnail } from '@/components/previews/card-preview'
import { activeAyah, usePlayer } from '@/components/previews/recitation-player'
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
            <p className="text-sm font-medium text-brand">The world's largest Quranic dataset for app developers</p>
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
  translation: 'translationPreview',
  morphology: 'morphologyPreview',
} as const satisfies Record<SampleType, keyof SiteHomeShow>

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
        {/* A bento grid in taxonomy order: the sampled categories take two columns, so each row
            of four columns is full; `dense` lets a one-column card fill a gap at two columns. */}
        <ul className="mt-10 grid gap-3 md:grid-flow-dense md:grid-cols-2 lg:grid-cols-4">
          {categories.map((category) => {
            const sample = samples.find((candidate) => candidate.category === category.key)
            return (
              <li key={category.key} className={cn('min-w-0', sample && 'md:col-span-2')}>
                <CategoryCard category={category} catalogPages={catalogPages}>
                  {sample ? (
                    <SampleWell
                      sample={sample}
                      preview={props[PREVIEW_PROPS[sample.type]]}
                      catalogPages={catalogPages}
                    />
                  ) : (
                    <Sketch category={category.key} />
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
      className="group relative flex h-full flex-col gap-5 rounded-2xl bg-card p-4 shadow-xs transition-shadow hover:shadow-md sm:p-5"
      data-testid="library-card"
      data-category={category.key}
    >
      <div className="flex items-start gap-3">
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

const WELL = 'flex min-h-32 flex-1 flex-col rounded-xl bg-surface p-4 md:min-h-40'

// A sampled type's well: a part of its sample's preview, loaded once the card is near the screen,
// and a link to the sample's own page, where the whole preview is.
function SampleWell({
  sample,
  preview,
  catalogPages,
}: {
  sample: SiteSample
  preview: SiteHomeShow[(typeof PREVIEW_PROPS)[SampleType]]
  catalogPages: boolean
}) {
  return (
    <div className="flex flex-1 flex-col gap-3">
      <WhenVisible
        data={PREVIEW_PROPS[sample.type]}
        buffer={400}
        fallback={<Skeleton className={cn(WELL, 'min-h-48')} />}
      >
        <div className={cn(WELL, 'min-h-48 gap-4')} data-testid="sample-preview" data-type={sample.type}>
          <SamplePreview preview={preview} />
        </div>
      </WhenVisible>
      <p className="truncate text-sm text-muted-foreground">
        From{' '}
        <NavAnchor
          link={{ href: detailResources({ type: sample.type, id: sample.toParam }).url, inertia: catalogPages }}
          className="relative z-10 text-foreground underline-offset-4 hover:underline"
        >
          {sample.name}
        </NavAnchor>
      </p>
    </div>
  )
}

function SamplePreview({ preview }: { preview: SiteHomeShow[(typeof PREVIEW_PROPS)[SampleType]] }) {
  switch (preview?.kind) {
    case 'recitation':
      return <AyahPlayer preview={preview} />
    case 'layout':
      return <PageThumbnail page={preview.page} />
    case 'text':
      return <AyahTranslation preview={preview} />
    case 'records':
      return <WordParts preview={preview} />
    default:
      return <p className="m-auto text-sm text-muted-foreground">No preview of this resource.</p>
  }
}

// The surah's audio, one ayah on screen at a time: the one being recited, where the ayahs have
// times. Each ayah is a step of the bar, as long as its recitation, and plays from its start.
function AyahPlayer({ preview }: { preview: PreviewsRecitation }) {
  const { surah, ayahs, tracks, highlights } = preview
  const { audio, events, track, playing, started, ms, duration, play, pause } = usePlayer(tracks)
  const timed = highlights ? ayahs.filter((ayah) => ayah.track !== null && ayah.from !== null) : []
  const active = (started && activeAyah(ayahs, track, ms)) || null
  const shown = active ?? ayahs[0]

  return (
    <div className="flex flex-1 flex-col gap-4" data-active-ayah={active?.key ?? ''}>
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
        <p className="min-w-0 flex-1 truncate text-sm font-medium">Surah {surah.name}</p>
        <span className="font-mono text-xs text-muted-foreground tabular-nums">{shown?.key}</span>
      </div>
      {shown && (
        <p dir="rtl" lang="ar" className="my-auto text-center font-arabic text-2xl leading-loose text-balance">
          {shown.text}
        </p>
      )}
      {timed.length > 0 ? (
        <div dir="rtl" className="flex gap-1">
          {timed.map((ayah) => {
            const end = ayah.to ?? duration
            const done = ayah.track! < track || (ayah.track === track && end > 0 && ms >= end)
            const progress = ayah.key === active?.key ? ((ms - ayah.from!) / Math.max(end - ayah.from!, 1)) * 100 : 0
            return (
              <button
                key={ayah.key}
                type="button"
                aria-label={`Play from ayah ${ayah.key}`}
                onClick={() => play(ayah.track!, ayah.from!)}
                className="group/ayah relative z-10 h-4 min-w-2 rounded-full outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50"
                style={{ flexGrow: Math.max(end - ayah.from!, 1) }}
              >
                <span className="absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 overflow-hidden rounded-full bg-border group-hover/ayah:bg-muted-foreground/40">
                  <span
                    className="absolute inset-y-0 start-0 bg-cat-audio"
                    style={{ width: `${done ? 100 : Math.min(progress, 100)}%` }}
                  />
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
function PageThumbnail({ page }: { page: PreviewsMushafPage }) {
  return (
    <div className="flex flex-1 flex-col items-center gap-4 sm:flex-row sm:gap-6">
      <div className="flex flex-col gap-1 self-start sm:flex-1 sm:self-center">
        <p className="headline text-3xl tabular-nums">{number(page.pagesCount)}</p>
        <p className="text-sm text-pretty text-muted-foreground">pages, line for line as printed</p>
      </div>
      <LayoutThumbnail preview={{ kind: 'layout', page }} className="text-[11px]" />
    </div>
  )
}

// One ayah and its translation at a time, stepped through the surah.
function AyahTranslation({ preview }: { preview: PreviewsText }) {
  const { entries, locale } = preview
  // Ayah 1:2, as the catalog's cards show, where the preview has it.
  const [index, setIndex] = React.useState(() => Math.max(entries.length > 1 ? 1 : 0, 0))
  const entry = entries[index]
  if (!entry) return null
  const step = (by: number) => setIndex((index + by + entries.length) % entries.length)

  return (
    <div className="flex flex-1 flex-col gap-3">
      <p dir="rtl" lang="ar" className="font-arabic text-2xl leading-loose text-balance">
        {entry.ayahs.map((ayah) => ayah.text).join(' ')}
      </p>
      {entry.text !== null && (
        <Html html={entry.text} locale={locale} className="line-clamp-4 text-pretty [&_sup]:hidden" />
      )}
      <div className="mt-auto flex items-center gap-2 pt-1">
        <StepButton label="Previous ayah" onClick={() => step(-1)}>
          <ChevronLeftIcon />
        </StepButton>
        <span className="w-10 text-center font-mono text-xs text-muted-foreground tabular-nums">{entry.key}</span>
        <StepButton label="Next ayah" onClick={() => step(1)}>
          <ChevronRightIcon />
        </StepButton>
        <span className="ms-auto text-xs text-muted-foreground uppercase">{locale.code}</span>
      </div>
    </div>
  )
}

function StepButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="relative z-10 flex size-8 items-center justify-center rounded-full border bg-card text-muted-foreground transition-colors outline-none hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 [&_svg]:size-4"
    >
      {children}
    </button>
  )
}

// The words of the start of the Quran; the chosen one is shown beside its data (a root, a lemma
// or a grammar term, as the sample has it).
function WordParts({ preview }: { preview: PreviewsRecords }) {
  const words = preview.records.filter((record) => record.arabic)
  const [index, setIndex] = React.useState(0)
  const word = words[index]
  if (!word) return null
  const data = word.tags.length > 0 ? word.tags : [word.text ?? '']

  return (
    <div className="flex flex-1 flex-col gap-4">
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

// What a category's data is like, for the categories without a sample: drawn, not loaded.
function Sketch({ category }: { category: SiteCategoryCount['key'] }) {
  return (
    <div className={cn(WELL, 'justify-center gap-3')} aria-hidden="true">
      {SKETCHES[category]}
    </div>
  )
}

const chip = 'rounded-md border bg-card px-2 py-0.5 text-xs text-muted-foreground'

const SKETCHES: Partial<Record<SiteCategoryCount['key'], React.ReactNode>> = {
  script: (
    <>
      <p dir="rtl" lang="ar" className="text-center font-arabic text-3xl leading-loose">
        بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ
      </p>
      <div className="flex flex-wrap justify-center gap-1.5">
        {['Madani', 'IndoPak', 'Tajweed', 'Page fonts'].map((label) => (
          <span key={label} className={chip}>
            {label}
          </span>
        ))}
      </div>
    </>
  ),
  // Seven ayahs and one commentary entry that covers three of them.
  tafsir: (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-7 gap-1">
        {[1, 2, 3, 4, 5, 6, 7].map((ayah) => (
          <span
            key={ayah}
            className={cn(
              'flex h-8 items-center justify-center rounded-md border bg-card font-mono text-xs',
              ayah >= 2 && ayah <= 4 ? 'border-cat-tafsir text-cat-tafsir' : 'text-muted-foreground',
            )}
          >
            {ayah}
          </span>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1">
        <span className="col-span-3 col-start-2 h-2 rounded-b-md border-x border-b border-cat-tafsir" />
      </div>
      <p className="text-center text-xs text-muted-foreground">One entry for ayahs 2 to 4</p>
    </div>
  ),
  topics: (
    <div className="flex flex-col items-center gap-2">
      <span className="rounded-full bg-card px-3 py-1 text-sm font-medium text-cat-topics shadow-xs">Mercy</span>
      <span className="h-3 w-px bg-border" />
      <div className="flex flex-wrap justify-center gap-1.5 font-mono">
        {['1:1', '1:3', '7:156', '21:107'].map((key) => (
          <span key={key} className={chip}>
            {key}
          </span>
        ))}
      </div>
    </div>
  ),
  // The 30 juz, with the counts of the units the metadata marks.
  metadata: (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-30 gap-0.5">
        {Array.from({ length: 30 }, (_, juz) => (
          <span key={juz} className={cn('h-7 rounded-[2px]', juz % 2 ? 'bg-cat-metadata/35' : 'bg-cat-metadata/60')} />
        ))}
      </div>
      <div className="grid grid-cols-3 gap-2 text-center">
        {[
          ['114', 'surahs'],
          ['6,236', 'ayahs'],
          ['30', 'juz'],
        ].map(([value, label]) => (
          <span key={label} className="flex flex-col">
            <span className="font-mono text-sm tabular-nums">{value}</span>
            <span className="text-xs text-muted-foreground">{label}</span>
          </span>
        ))}
      </div>
    </div>
  ),
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
            <span className="inline-flex h-9 shrink-0 items-center gap-1.5 rounded-md bg-brand px-3 text-sm font-medium text-on-brand transition-colors group-hover:bg-brand/85">
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

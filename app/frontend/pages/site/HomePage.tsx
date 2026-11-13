import { router, WhenVisible } from '@inertiajs/react'
import { ArrowRightIcon, GitForkIcon, PlusIcon, StarIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import type { PreviewNavigation, PreviewQuery } from '@/components/previews/navigation'
import { Preview } from '@/components/previews/preview'
import { AppIcon } from '@/components/qul/app-icon'
import { GitHubMark, ResourceIcon } from '@/components/qul/icons'
import { NavAnchor } from '@/components/qul/nav'
import { ShardRing } from '@/components/qul/shard-ring'
import { ToolCard } from '@/components/qul/tool-card'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/misc'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { formatStars, REPO, REPO_URL, useGitHubStars } from '@/lib/github'
import { cn } from '@/lib/utils'
import { appsDirectory, catalogResources, catalogType, detailResources } from '@/routes'
import type { SiteCategoryCount, SiteHomeShow, SiteSample } from '@/types/serializers'

// The shard ring draws on this colour (renderer.js BACKGROUND, as displayed), so the panel and
// the canvas meet without a seam.
const RING_BG = '#030304'

const number = (count: number) => count.toLocaleString('en')

// The home page (/): the hero with the shard ring and the catalog counts, the apps built with
// QUL, the library (a tab per sample of the data, then the categories) and the open source band
// with three contribution tools. From the v8 design
// (ds/src/app/pages/home.tsx); its sections for pages outside this sprint (the wizard, kits, the
// MCP server) are left out.
export default function HomePage(props: SiteHomeShow) {
  return (
    <SiteShell>
      <Hero {...props} />
      <Apps {...props} />
      <Library {...props} />
      <OpenSource {...props} />
      <Closing catalogPages={props.catalogPages} />
    </SiteShell>
  )
}

function catalogLink(catalogPages: boolean) {
  return { href: catalogResources.index().url, inertia: catalogPages }
}

/* ---------------- hero ---------------- */

function Hero({ resources, languages, recitations, catalogPages }: SiteHomeShow) {
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
              <Button size="lg" variant="brand" asChild>
                <NavAnchor link={catalogLink(catalogPages)}>
                  Browse the library <ArrowRightIcon />
                </NavAnchor>
              </Button>
              <Button size="lg" variant="outline" asChild>
                <a href="/docs/getting-started">Read the docs</a>
              </Button>
              <HeroStar />
            </div>
            <dl className="mt-2 grid grid-cols-3 gap-4 border-t border-white/10 pt-5 sm:flex sm:gap-x-14">
              <Stat value={resources} label="resources" />
              <Stat value={languages} label="languages" />
              <Stat value={recitations} label="recitations" />
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

/* ---------------- the library: a tabbed look at the data, then the categories ---------------- */

type SampleType = SiteSample['type']

// The prop that holds each tab's preview (Site::HomeShowResource::PREVIEWS). The first response
// carries none of them: each loads once its tab is open and near the screen.
const PREVIEW_PROPS = {
  recitation: 'recitationPreview',
  'mushaf-layout': 'mushafLayoutPreview',
  translation: 'translationPreview',
  morphology: 'morphologyPreview',
} as const satisfies Record<SampleType, keyof SiteHomeShow>

const TABS: Record<SampleType, { tab: string; title: string; text: (count: string) => string }> = {
  recitation: {
    tab: 'Recitations',
    title: 'Recitations, timed to the text',
    text: (count) =>
      `${count} recitations, surah by surah and ayah by ayah. Many have the time of each ayah and word, so your app can highlight the text as it plays.`,
  },
  'mushaf-layout': {
    tab: 'Mushaf layouts',
    title: 'Mushaf pages, line for line',
    text: (count) =>
      `Page, line and word positions for ${count} printed mushafs, so the page on screen matches the one in people's hands.`,
  },
  translation: {
    tab: 'Translations',
    title: 'Translations in many languages',
    text: (count) => `${count} translations, ayah by ayah and word by word, each with its source and licence.`,
  },
  morphology: {
    tab: 'Morphology',
    title: 'Every word, parsed',
    text: () => 'Roots, lemmas, stems and grammar for each word of the Quran, for word-by-word study tools and search.',
  },
}

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
        {samples.length > 0 && <Showcase {...props} />}
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {categories.map((category) => (
            <CategoryRow key={category.key} category={category} catalogPages={catalogPages} />
          ))}
        </div>
      </Container>
    </Section>
  )
}

// One tab per sample. A tab's content is mounted only while it is open, so switching tabs stops
// the recitation that was playing.
function Showcase(props: SiteHomeShow) {
  const { samples } = props
  const [open, setOpen] = React.useState(samples[0].type)

  return (
    <Tabs value={open} onValueChange={(value) => setOpen(value as SampleType)} className="mt-10 gap-6">
      <div className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        <TabsList>
          {samples.map((sample) => (
            <TabsTrigger key={sample.type} value={sample.type}>
              {TABS[sample.type].tab}
            </TabsTrigger>
          ))}
        </TabsList>
      </div>
      {samples.map((sample) => (
        <TabsContent key={sample.type} value={sample.type}>
          <SampleTab
            sample={sample}
            prop={PREVIEW_PROPS[sample.type]}
            preview={props[PREVIEW_PROPS[sample.type]]}
            catalogPages={props.catalogPages}
          />
        </TabsContent>
      ))}
    </Tabs>
  )
}

function SampleTab({
  sample,
  prop,
  preview,
  catalogPages,
}: {
  sample: SiteSample
  prop: (typeof PREVIEW_PROPS)[SampleType]
  preview: SiteHomeShow[(typeof PREVIEW_PROPS)[SampleType]]
  catalogPages: boolean
}) {
  const copy = TABS[sample.type]
  const page = (query: PreviewQuery = {}) => detailResources({ type: sample.type, id: sample.toParam }, { query }).url
  // Paging the preview opens the resource's own page there.
  const go = (query: PreviewQuery) => (catalogPages ? router.visit(page(query)) : window.location.assign(page(query)))
  const navigation: PreviewNavigation = {
    navigate: go,
    showView: (view, query) => go({ ...query, view }),
    loading: false,
  }

  return (
    <div className="grid items-center gap-10 rounded-2xl bg-surface p-6 sm:p-10 lg:grid-cols-[0.8fr_1fr] lg:gap-16 lg:p-14">
      <div className="flex flex-col items-start gap-4">
        <ResourceIcon category={sample.category} size="md" />
        <h3 className="headline text-2xl sm:text-3xl">{copy.title}</h3>
        <p className="max-w-md text-pretty text-muted-foreground">{copy.text(number(sample.count))}</p>
        <Button variant="outline" className="mt-2" asChild>
          <NavAnchor link={{ href: catalogType({ type: sample.type }).url, inertia: catalogPages }}>
            Browse {copy.tab.toLowerCase()} <ArrowRightIcon />
          </NavAnchor>
        </Button>
      </div>
      <div className="flex min-w-0 flex-col gap-3">
        <WhenVisible data={prop} buffer={400} fallback={<Skeleton className="h-64 rounded-xl" />}>
          <Preview preview={preview} navigation={navigation} />
        </WhenVisible>
        <p className="text-sm text-muted-foreground">
          From{' '}
          <NavAnchor
            link={{ href: page(), inertia: catalogPages }}
            className="text-foreground underline-offset-4 hover:underline"
          >
            {sample.name}
          </NavAnchor>
        </p>
      </div>
    </div>
  )
}

function CategoryRow({ category, catalogPages }: { category: SiteCategoryCount; catalogPages: boolean }) {
  return (
    <NavAnchor
      link={{ href: catalogResources.index({ query: { category: category.key } }).url, inertia: catalogPages }}
      className="group flex min-w-0 items-center gap-4 rounded-xl bg-card p-4 shadow-xs transition-shadow hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
    >
      <ResourceIcon category={category.key} size="md" />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate font-medium">{category.label}</span>
        <span className="truncate text-sm text-muted-foreground">{category.hint}</span>
      </span>
      <span className="font-mono text-xs text-muted-foreground tabular-nums">{number(category.count)}</span>
      <ArrowRightIcon className="size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:text-foreground" />
    </NavAnchor>
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
            <span className="inline-flex h-9 shrink-0 items-center gap-1.5 rounded-md bg-brand px-3 text-sm font-medium text-foreground transition-colors group-hover:bg-brand/85">
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

function Closing({ catalogPages }: { catalogPages: boolean }) {
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
          <Button size="lg" variant="brand" asChild>
            <NavAnchor link={catalogLink(catalogPages)}>
              Browse the library <ArrowRightIcon />
            </NavAnchor>
          </Button>
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

import { ArrowRightIcon, GitForkIcon, PlusIcon, StarIcon } from 'lucide-react'
import type { ReactNode } from 'react'

import { Container, SiteShell } from '@/components/layout'
import { AppIcon } from '@/components/qul/app-icon'
import { GitHubMark, ResourceIcon } from '@/components/qul/icons'
import { NavAnchor } from '@/components/qul/nav'
import { ShardRing } from '@/components/qul/shard-ring'
import { Button } from '@/components/ui/button'
import { formatStars, REPO, REPO_URL, useGitHubStars } from '@/lib/github'
import { cn } from '@/lib/utils'
import { appsDirectory, catalogResources, catalogType } from '@/routes'
import type { SiteCategoryCount, SiteHomeShow } from '@/types/serializers'

// The shard ring draws on this colour (renderer.js BACKGROUND, as displayed), so the panel and
// the canvas meet without a seam.
const RING_BG = '#030304'

const number = (count: number) => count.toLocaleString('en')

// The home page (/): the hero with the shard ring and the catalog counts, the apps built with
// QUL, the catalog by category and the open source band. From the v7 design
// (ds/src/app/pages/home.tsx); its sections for pages outside this sprint (the wizard, kits, the
// MCP server) are left out.
export default function HomePage(props: SiteHomeShow) {
  return (
    <SiteShell>
      <Hero {...props} />
      <Apps {...props} />
      <Library {...props} />
      <OpenSource />
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
      className="hidden h-10 items-center gap-2 rounded-md px-3 text-sm font-medium text-white/80 transition-colors outline-none hover:bg-white/5 hover:text-white focus-visible:ring-[3px] focus-visible:ring-ring/50 sm:inline-flex"
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

function Apps({ showcase, appsCount, appsPage, submitUrl }: SiteHomeShow) {
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
          <div className="mt-1 flex flex-wrap gap-2">
            {appsPage && (
              <Button variant="outline" size="sm" asChild>
                <NavAnchor link={{ href: appsDirectory().url, inertia: true }}>
                  See the apps <ArrowRightIcon />
                </NavAnchor>
              </Button>
            )}
            <Button variant="ghost" size="sm" asChild>
              <a href={submitUrl} target="_blank" rel="noreferrer">
                <PlusIcon /> Submit your app
              </a>
            </Button>
          </div>
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

/* ---------------- the catalog by category ---------------- */

function Library({ categories, resources, catalogPages }: SiteHomeShow) {
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
        <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {categories.map((category) => (
            <CategoryCard key={category.key} category={category} catalogPages={catalogPages} />
          ))}
        </div>
      </Container>
    </Section>
  )
}

function CategoryCard({ category, catalogPages }: { category: SiteCategoryCount; catalogPages: boolean }) {
  return (
    <section
      aria-labelledby={`category-${category.key}`}
      className="flex flex-col gap-3 rounded-xl bg-card p-4 shadow-xs"
    >
      <div className="flex items-center gap-3">
        <ResourceIcon category={category.key} size="md" />
        <h3 id={`category-${category.key}`} className="min-w-0 flex-1 font-medium">
          {category.label}
        </h3>
        <span className="font-mono text-xs text-muted-foreground tabular-nums">{number(category.count)}</span>
      </div>
      <ul className="flex flex-col">
        {category.types.map((type) => (
          <li key={type.key}>
            <NavAnchor
              link={{ href: catalogType({ type: type.key }).url, inertia: catalogPages }}
              className="group -mx-2 flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent"
            >
              <span className="min-w-0 flex-1 truncate">{type.title}</span>
              <span className="font-mono text-xs text-muted-foreground tabular-nums">{number(type.count)}</span>
              <ArrowRightIcon className="size-3.5 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:text-foreground" />
            </NavAnchor>
          </li>
        ))}
      </ul>
    </section>
  )
}

/* ---------------- open source ---------------- */

function OpenSource() {
  const stars = useGitHubStars()
  return (
    <Section>
      <Container className="flex flex-col items-start gap-6">
        <SectionTitle
          title="Open source, checked in public"
          text="QUL's code and data live on GitHub. Volunteers proofread every resource, and each fix ships to every app built on QUL. Star the repo to follow releases."
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
        <Button variant="outline" asChild>
          <a href={`${REPO_URL}/fork`} target="_blank" rel="noreferrer">
            <GitForkIcon /> Fork the repo
          </a>
        </Button>
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
function Section({ className, children }: { className?: string; children: ReactNode }) {
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

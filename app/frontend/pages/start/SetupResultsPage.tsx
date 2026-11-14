import { Link } from '@inertiajs/react'
import { ArrowRightIcon, PencilIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { ResourceIcon } from '@/components/qul/icons'
import { PageHeader } from '@/components/qul/page-header'
import { ResultCard } from '@/components/qul/start'
import { catalogResources } from '@/routes'
import type { StartSetupResults } from '@/types/serializers'

function joinAnd(items: string[]) {
  return items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`
}

// /resources?goal=…: the catalog filtered for the answers of the guided setup. The banner says
// what it is filtered for and links back to the setup with the answers kept; the checklist names
// each need, and a section per need shows its first resources and links to the catalog search
// that lists all of them. With nothing marked recommended yet, the checklist names needs, not picks.
export default function SetupResultsPage({
  goals,
  platforms,
  formats,
  editPath,
  sections,
  total,
  vocabularies,
}: StartSetupResults) {
  const categoryOf = (type: string) =>
    vocabularies.types.find((option) => option.key === type)?.category.key ?? 'metadata'

  return (
    <SiteShell>
      <Container className="flex flex-col gap-6 pt-10 pb-2 sm:pt-12">
        <div className="flex flex-col gap-3 rounded-xl bg-brand-subtle px-4 py-3 text-sm justify-between sm:flex-row sm:items-center">
          <p className="min-w-0">
            <span className="font-medium">
              Filtered for your {joinAnd(goals.map((goal) => goal.replace(/ app$/, '')))} app
            </span>
            {platforms.length > 0 && <span className="text-foreground/60"> · {joinAnd(platforms)}</span>}
            {formats.length > 0 && <span className="text-foreground/60"> · {formats.join(' or ')} files</span>}
          </p>
          <div className="flex shrink-0 flex-wrap items-center gap-x-4 gap-y-1">
            <Link
              href={editPath}
              className="inline-flex items-center gap-1.5 font-medium underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground"
            >
              <PencilIcon className="size-3.5" /> Edit answers
            </Link>
            <Link
              href={catalogResources.index().url}
              className="text-foreground/60 underline decoration-foreground/30 underline-offset-4 hover:text-foreground"
            >
              Show everything
            </Link>
          </div>
        </div>
        <PageHeader
          title="Resources for your app"
          count={total}
          description="Everything below fits your answers. Pick one of each; open a need to see all of its resources and filter them further."
        />
        <nav aria-label="Your app needs" className="flex flex-col gap-3 rounded-xl bg-card p-4 shadow-xs">
          <p className="text-sm font-medium">Your app needs</p>
          <ul className="flex flex-wrap gap-2">
            {sections.map((section) => (
              <li key={section.key}>
                <a
                  href={`#need-${section.key}`}
                  className="inline-flex h-8 items-center gap-1.5 rounded-full border px-3 text-sm transition-colors hover:border-foreground/30"
                >
                  <ResourceIcon category={categoryOf(section.type)} variant="plain" size="sm" />
                  {section.label}
                  <span className="text-xs text-muted-foreground tabular-nums">{section.total}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>
      </Container>

      <Container className="flex flex-col gap-12 py-10">
        {sections.map((section) => (
          <section
            key={section.key}
            id={`need-${section.key}`}
            aria-labelledby={`need-${section.key}-title`}
            className="flex scroll-mt-24 flex-col gap-4"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
              <h2
                id={`need-${section.key}-title`}
                className="flex items-center gap-2 text-xl font-medium tracking-tight"
              >
                <ResourceIcon category={categoryOf(section.type)} variant="plain" size="sm" />
                {section.label}
                <span className="text-sm font-normal text-muted-foreground tabular-nums">{section.total}</span>
              </h2>
              {section.total > section.results.length && (
                <Link
                  href={section.catalogPath}
                  className="inline-flex items-center gap-1 text-sm font-medium underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground"
                >
                  See all {section.total} <ArrowRightIcon className="size-3.5" />
                </Link>
              )}
            </div>
            {section.results.length > 0 ? (
              <ul aria-label={section.label} className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {section.results.map((result) => (
                  <li key={result.id} className="flex">
                    <ResultCard className="flex-1" result={result} vocabularies={vocabularies} />
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-muted-foreground">Nothing in the library fits this yet.</p>
            )}
          </section>
        ))}
      </Container>
    </SiteShell>
  )
}

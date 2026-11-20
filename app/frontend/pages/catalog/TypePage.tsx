import { Link, router, usePage } from '@inertiajs/react'
import { ChevronDownIcon, ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { EmptyState } from '@/components/qul/catalog'
import { RequestCard } from '@/components/qul/request-dialog'
import { SearchInput } from '@/components/qul/chrome'
import { ResourceIcon } from '@/components/qul/icons'
import { PageHeader } from '@/components/qul/page-header'
import { CardPreview } from '@/components/previews/card-preview'
import { ResourceCard } from '@/components/qul/resource-card'
import { RecommendedBadge, StatusBadge } from '@/components/qul/status-badge'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/misc'
import { cn } from '@/lib/utils'
import { catalogResourcePreview, catalogType, detailResources, resources as catalog } from '@/routes'
import type {
  CatalogComparison,
  CatalogComparisonColumn,
  CatalogComparisonRow,
  CatalogOption,
  CatalogResourceCard,
  CatalogResourceRef,
  CatalogType,
  CatalogTypeSearch,
  CatalogTypesShow,
} from '@/types/serializers'

const SEARCH_PROPS = ['resources', 'search']
const TYPING_DEBOUNCE_MS = 300

type SearchState = Pick<CatalogTypeSearch, 'q' | 'language' | 'page'>

function detailHref(resource: CatalogResourceRef) {
  return detailResources({ type: resource.type, id: resource.toParam }).url
}

function labelOf(options: CatalogOption[], key: string) {
  return options.find((option) => option.key === key)?.label ?? key
}

function isOlder(resource: CatalogResourceCard) {
  return resource.status === 'legacy' || resource.status === 'superseded'
}

function cardFacts(type: CatalogType, resource: CatalogResourceCard) {
  return [type.label, resource.language, resource.granularity, resource.scriptFamily].filter((fact): fact is string =>
    Boolean(fact),
  )
}

function Cards({
  label,
  type,
  resources,
  statuses,
  formats,
}: {
  label: string
  type: CatalogType
  resources: CatalogResourceCard[]
  statuses: CatalogOption[]
  formats: CatalogOption[]
}) {
  return (
    <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4" aria-label={label}>
      {resources.map((resource) => {
        const badges = [
          resource.recommendation && (
            <RecommendedBadge key="recommended" reviewed={resource.recommendation === 'reviewed'} />
          ),
          resource.status !== 'stable' && (
            <StatusBadge
              key="status"
              status={resource.status}
              label={labelOf(statuses, resource.status)}
              supersededBy={
                resource.supersededBy && { name: resource.supersededBy.name, href: detailHref(resource.supersededBy) }
              }
            />
          ),
        ].filter(Boolean)

        return (
          <li key={resource.id} className="flex">
            <ResourceCard
              className="flex-1"
              title={resource.name}
              bundleId={resource.id}
              href={detailHref(resource)}
              category={type.category.key}
              facts={cardFacts(type, resource)}
              summary={resource.summary}
              status={badges.length > 0 ? badges : undefined}
              formats={resource.formats.map((format) => labelOf(formats, format))}
              muted={isOlder(resource)}
              preview={
                resource.previewKind && (
                  <CardPreview
                    kind={resource.previewKind}
                    url={catalogResourcePreview({ type: resource.type, slug: resource.toParam }).url}
                  />
                )
              }
            />
          </li>
        )
      })}
    </ul>
  )
}

function ComparisonCell({
  column,
  row,
  statuses,
}: {
  column: CatalogComparisonColumn
  row: CatalogComparisonRow
  statuses: CatalogOption[]
}) {
  switch (column.key) {
    case 'script_family':
      return <TableCell>{row.scriptFamily ?? '–'}</TableCell>
    case 'pages':
      return <TableCell className="text-right tabular-nums">{row.pages ?? '–'}</TableCell>
    case 'lines_per_page':
      return <TableCell className="text-right tabular-nums">{row.linesPerPage ?? '–'}</TableCell>
    case 'rendering':
      return <TableCell className="text-muted-foreground">{row.rendering ?? '–'}</TableCell>
    case 'font':
      return (
        <TableCell>
          {row.font ? (
            <Link href={detailHref(row.font)} className="hover:underline">
              {row.font.name}
            </Link>
          ) : (
            '–'
          )}
        </TableCell>
      )
    case 'status':
      return (
        <TableCell>
          <StatusBadge status={row.status} label={labelOf(statuses, row.status)} />
        </TableCell>
      )
  }
}

// The name column stays in view while the rest of the table scrolls under it; the inset shadow
// is its edge (a border on a sticky cell scrolls away with border-collapse).
const FIRST_COLUMN = 'sticky left-0 z-10 bg-card shadow-[inset_-1px_0_0_var(--color-border)]'

function ComparisonTable({
  type,
  comparison,
  statuses,
}: {
  type: CatalogType
  comparison: CatalogComparison
  statuses: CatalogOption[]
}) {
  return (
    <section aria-labelledby="comparison" className="flex flex-col gap-4">
      <h2 id="comparison" className="text-lg font-medium tracking-tight">
        Comparison
      </h2>
      {/* On a phone the table scrolls sideways inside its container, with the names kept in view. */}
      <div className="overflow-hidden rounded-xl bg-card shadow-xs">
        <Table aria-labelledby="comparison">
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead className={cn(FIRST_COLUMN, 'px-5')}>{type.label}</TableHead>
              {comparison.columns.map((column) => (
                <TableHead
                  key={column.key}
                  className={cn(column.key === 'pages' || column.key === 'lines_per_page' ? 'text-right' : undefined)}
                >
                  {column.label}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {comparison.rows.map((row) => (
              <TableRow key={row.id}>
                <TableCell
                  className={cn(
                    FIRST_COLUMN,
                    'min-w-36 px-5 font-medium [tr:hover>&]:bg-accent whitespace-normal sm:min-w-40',
                  )}
                >
                  <Link href={detailHref(row)} className="hover:underline">
                    {row.name}
                  </Link>
                </TableCell>
                {comparison.columns.map((column) => (
                  <ComparisonCell key={column.key} column={column} row={row} statuses={statuses} />
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </section>
  )
}

// The query string of a type page search, without the values that are the defaults.
function searchUrl(type: CatalogType, { q, language, page }: SearchState) {
  return catalogType(type.key, { query: { q: q || null, language, page: page > 1 ? page : null } }).url
}

// Search, the language filter and the pages of a type with many resources. As on the catalog,
// the state is in the query string: a language change adds a history entry, typing replaces it.
function TypeSearch({ type, search }: { type: CatalogType; search: CatalogTypeSearch }) {
  const [query, setQuery] = React.useState(search.q)
  const [sent, setSent] = React.useState(search.q)
  const visit = (next: SearchState, replace = false) =>
    router.get(searchUrl(type, next), {}, { only: SEARCH_PROPS, preserveState: true, preserveScroll: true, replace })

  React.useEffect(() => {
    const q = query.trim()
    if (q === sent) return
    const timer = window.setTimeout(() => {
      setSent(q)
      visit({ q, language: search.language, page: 1 }, true)
    }, TYPING_DEBOUNCE_MS)
    return () => window.clearTimeout(timer)
  })

  return (
    <div className="flex flex-wrap items-center gap-2 sm:gap-3">
      <SearchInput
        aria-label={`Search ${type.title.toLowerCase()}`}
        placeholder="Search by name or language…"
        className="min-w-0 flex-1 basis-56"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <label className="flex h-9 items-center gap-2 text-sm text-muted-foreground">
        Language
        <select
          value={search.language ?? ''}
          onChange={(event) => {
            const q = query.trim()
            setSent(q)
            visit({ q, language: event.target.value || null, page: 1 })
          }}
          className="h-9 max-w-48 rounded-lg border bg-card px-2 text-sm text-foreground shadow-xs"
        >
          <option value="">All languages</option>
          {search.languages.map((language) => (
            <option key={language.key} value={language.key}>
              {language.name} ({language.count})
            </option>
          ))}
        </select>
      </label>
    </div>
  )
}

function Pages({ type, search }: { type: CatalogType; search: CatalogTypeSearch }) {
  const link = (page: number) => ({
    href: searchUrl(type, { ...search, page }),
    only: SEARCH_PROPS,
    preserveState: true,
  })

  return (
    <nav aria-label="Pages" className="flex items-center justify-between gap-3 text-sm">
      {search.page > 1 ? (
        <Button variant="outline" size="sm" asChild>
          <Link {...link(search.page - 1)} rel="prev">
            <ChevronLeftIcon /> Previous
          </Link>
        </Button>
      ) : (
        <span />
      )}
      <span className="text-muted-foreground tabular-nums">
        Page {search.page} of {search.pages}
      </span>
      {search.page < search.pages ? (
        <Button variant="outline" size="sm" asChild>
          <Link {...link(search.page + 1)} rel="next">
            Next <ChevronRightIcon />
          </Link>
        </Button>
      ) : (
        <span />
      )}
    </nav>
  )
}

// /resources/:type: the type's description and a link to its format docs; where the type has
// status data, which one to pick, with recommended resources first and older versions collapsed;
// the comparison table for layouts, scripts and fonts; a card for each published resource (with
// search, a language filter and pages when the type has many); and the request card.
export default function TypePage({
  type,
  types,
  resources,
  total,
  search,
  statuses,
  formats,
  pick,
  guidePath,
  comparison,
}: CatalogTypesShow) {
  const { nav } = usePage().props
  const recommended = pick ? resources.filter((resource) => resource.recommendation) : []
  const older = pick ? resources.filter((resource) => !resource.recommendation && isOlder(resource)) : []
  const current = resources.filter((resource) => !recommended.includes(resource) && !older.includes(resource))

  return (
    <SiteShell>
      <Container className="pt-10 pb-2 sm:pt-12">
        <PageHeader
          breadcrumb={[{ label: 'Resources', href: catalog.index().url }, { label: type.title }]}
          icon={<ResourceIcon category={type.category.key} size="xl" />}
          eyebrow={type.category.label === type.title ? undefined : type.category.label}
          title={type.title}
          count={total}
          description={type.description}
          actions={
            guidePath && (
              // The guide is an old docs page, so a plain link.
              <Button variant="outline" asChild>
                <a href={guidePath}>{type.label} format docs</a>
              </Button>
            )
          }
        />
      </Container>

      <Container className="flex flex-col gap-12 py-10">
        {pick && (
          <section aria-labelledby="pick" className="flex flex-col gap-4">
            <div>
              <h2 id="pick" className="text-lg font-medium tracking-tight">
                Which one should I pick?
              </h2>
              <p className="mt-2 max-w-2xl text-muted-foreground">{pick}</p>
            </div>
            {recommended.length > 0 && (
              <Cards label="Recommended" type={type} resources={recommended} statuses={statuses} formats={formats} />
            )}
          </section>
        )}

        {comparison && <ComparisonTable type={type} comparison={comparison} statuses={statuses} />}

        {search && <TypeSearch type={type} search={search} />}

        {total === 0 && <p className="text-muted-foreground">No resources of this type are published yet.</p>}
        {search && resources.length === 0 && (
          <EmptyState title="Nothing matches this search" description="Try another word or language." />
        )}

        {current.length > 0 && (
          <section aria-labelledby={pick ? 'current' : undefined} className="flex flex-col gap-4">
            {pick && (
              <h2 id="current" className="flex items-baseline gap-3 text-lg font-medium tracking-tight">
                Current versions
                <span className="font-mono text-xs font-normal text-muted-foreground">{current.length}</span>
              </h2>
            )}
            <Cards label={type.title} type={type} resources={current} statuses={statuses} formats={formats} />
          </section>
        )}

        {older.length > 0 && (
          <details className="group flex flex-col gap-4">
            <summary className="flex w-fit cursor-pointer list-none items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground [&::-webkit-details-marker]:hidden">
              <ChevronDownIcon className="size-4 transition-transform group-open:rotate-180" aria-hidden="true" />
              Older versions ({older.length}), kept for apps that already use them
            </summary>
            <div className="pt-4">
              <Cards label="Older versions" type={type} resources={older} statuses={statuses} formats={formats} />
            </div>
          </details>
        )}

        {search && search.pages > 1 && <Pages type={type} search={search} />}

        <RequestCard link={nav.request} />
      </Container>

      <Container className="pb-12">
        <nav aria-labelledby="other-types" className="flex flex-col gap-3">
          <h2 id="other-types" className="text-lg font-medium tracking-tight">
            Other resource types
          </h2>
          <ul className="flex flex-wrap gap-2">
            {types.map((other) => (
              <li key={other.key}>
                <Link
                  href={catalogType(other.key).url}
                  aria-current={other.key === type.key ? 'page' : undefined}
                  className={cn(
                    'inline-flex h-8 items-center rounded-md border bg-card px-3 text-sm hover:bg-accent',
                    other.key === type.key && 'border-foreground font-medium',
                  )}
                >
                  {other.title}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </Container>
    </SiteShell>
  )
}

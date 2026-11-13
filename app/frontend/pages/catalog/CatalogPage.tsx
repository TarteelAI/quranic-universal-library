import { Link, router, usePage } from '@inertiajs/react'
import { ChevronLeftIcon, ChevronRightIcon, SlidersHorizontalIcon, XIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { EmptyState, FacetGroup, RequestCard, type FacetOption } from '@/components/qul/catalog'
import { SearchInput } from '@/components/qul/chrome'
import { PageHeader } from '@/components/qul/page-header'
import { CardPreview } from '@/components/previews/card-preview'
import { ResourceCard } from '@/components/qul/resource-card'
import { StatusBadge } from '@/components/qul/status-badge'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { catalogResourcePreview, catalogResources, detailResources } from '@/routes'
import type {
  CatalogFacetValue,
  CatalogOption,
  CatalogResourcesIndex,
  CatalogSearchFilters,
  CatalogSearchResult,
} from '@/types/serializers'

type Filters = CatalogSearchFilters
type SingleFacet = 'type' | 'language' | 'format' | 'granularity' | 'status'

// The props a search changes. The vocabularies arrive once, with the first page load.
const SEARCH_PROPS = ['filters', 'results', 'facets', 'total', 'page', 'pages']
const DEFAULT_SORT: Filters['sort'] = 'popular'
const TYPING_DEBOUNCE_MS = 300

// The query string of a search, without the values that are the defaults.
function searchUrl(filters: Filters) {
  return catalogResources.index({
    query: {
      q: filters.q || null,
      type: filters.type,
      language: filters.language,
      script: filters.script.length > 0 ? filters.script : null,
      format: filters.format,
      granularity: filters.granularity,
      status: filters.status,
      sort: filters.sort === DEFAULT_SORT ? null : filters.sort,
      page: filters.page > 1 ? filters.page : null,
    },
  }).url
}

// Filter changes add a history entry, so Back undoes them; typing replaces the current entry.
function search(filters: Filters, { replace = false, preserveScroll = true } = {}) {
  router.get(searchUrl(filters), {}, { only: SEARCH_PROPS, preserveState: true, preserveScroll, replace })
}

function counts(values: CatalogFacetValue[]) {
  return new Map(values.map(({ value, count }) => [value, count]))
}

function labelOf(options: CatalogOption[], key: string) {
  return options.find((option) => option.key === key)?.label ?? key
}

function plural(count: number, word: string) {
  return `${count} ${count === 1 ? word : `${word}s`}`
}

// /resources: catalog search. Every filter, the query, the sort and the page are in the query
// string, so each view is a link; the server searches (Catalog::SearchQuery) and this page shows
// the results, the facet counts and the controls.
export default function CatalogPage({
  filters,
  results,
  facets,
  total,
  page,
  pages,
  vocabularies,
}: CatalogResourcesIndex) {
  const { nav } = usePage().props
  const [query, setQuery] = React.useState(filters.q)
  // The query of the last search this page asked for. Typing searches once it pauses, unless a
  // filter change has sent the typed query along already.
  const [sent, setSent] = React.useState(filters.q)

  React.useEffect(() => {
    const q = query.trim()
    if (q === sent) return
    const timer = window.setTimeout(() => {
      setSent(q)
      search({ ...filters, q, page: 1 }, { replace: true })
    }, TYPING_DEBOUNCE_MS)
    return () => window.clearTimeout(timer)
  }, [query, sent, filters])

  const apply = (patch: Partial<Filters>) => {
    const next = { ...filters, q: query.trim(), page: 1, ...patch }
    setSent(next.q)
    search(next)
  }
  const toggle = (facet: SingleFacet, value: string) =>
    apply({ [facet]: filters[facet] === value ? null : value } as Partial<Filters>)
  const toggleScript = (value: string) =>
    apply({
      script: vocabularies.scriptFamilies
        .map((option) => option.key as Filters['script'][number])
        .filter((key) => (key === value) !== filters.script.includes(key)),
    })
  const clearAll = () => {
    setQuery('')
    setSent('')
    search({
      q: '',
      type: null,
      language: null,
      script: [],
      format: null,
      granularity: null,
      status: null,
      sort: filters.sort,
      page: 1,
    })
  }

  // Options in vocabulary order, so checkboxes stay put as counts change; values with no
  // results under the other filters are left out unless selected.
  const optionsFor = (
    options: CatalogOption[],
    values: CatalogFacetValue[],
    isChecked: (key: string) => boolean,
  ): FacetOption[] => {
    const count = counts(values)
    return options
      .map((option) => ({
        value: option.key,
        label: option.label,
        count: count.get(option.key) ?? 0,
        checked: isChecked(option.key),
      }))
      .filter((option) => option.count > 0 || option.checked)
  }
  const languageName = new Map(vocabularies.languages.map((language) => [language.key, language.name]))

  const groups = [
    {
      title: 'Type',
      onToggle: (value: string) => toggle('type', value),
      options: vocabularies.types
        .map((type) => ({
          value: type.key,
          label: type.label,
          count: counts(facets.type).get(type.key) ?? 0,
          checked: filters.type === type.key,
          category: type.category.key,
        }))
        .filter((option) => option.count > 0 || option.checked),
    },
    {
      title: 'Language',
      onToggle: (value: string) => toggle('language', value),
      limit: 8,
      options: facets.language.map(({ value, count }) => ({
        value,
        label: languageName.get(value) ?? value,
        count,
        checked: filters.language === value,
      })),
    },
    {
      title: 'Script',
      onToggle: toggleScript,
      options: optionsFor(vocabularies.scriptFamilies, facets.script, (key) =>
        filters.script.some((script) => script === key),
      ),
    },
    {
      title: 'Format',
      onToggle: (value: string) => toggle('format', value),
      options: optionsFor(vocabularies.formats, facets.format, (key) => filters.format === key),
    },
    {
      title: 'Granularity',
      onToggle: (value: string) => toggle('granularity', value),
      options: optionsFor(vocabularies.granularities, facets.granularity, (key) => filters.granularity === key),
    },
    {
      title: 'Status',
      onToggle: (value: string) => toggle('status', value),
      options: optionsFor(vocabularies.statuses, facets.status, (key) => filters.status === key),
    },
  ].filter((group) => group.options.length > 0)

  const facetControls = groups.map((group) => <FacetGroup key={group.title} {...group} />)

  const chips: { label: string; remove: () => void }[] = [
    ...(filters.q
      ? [
          {
            label: `“${filters.q}”`,
            remove: () => {
              setQuery('')
              apply({ q: '' })
            },
          },
        ]
      : []),
    ...(filters.type
      ? [{ label: labelOf(vocabularies.types, filters.type), remove: () => apply({ type: null }) }]
      : []),
    ...(filters.language
      ? [{ label: languageName.get(filters.language) ?? filters.language, remove: () => apply({ language: null }) }]
      : []),
    ...filters.script.map((script) => ({
      label: labelOf(vocabularies.scriptFamilies, script),
      remove: () => toggleScript(script),
    })),
    ...(filters.format
      ? [{ label: labelOf(vocabularies.formats, filters.format), remove: () => apply({ format: null }) }]
      : []),
    ...(filters.granularity
      ? [
          {
            label: labelOf(vocabularies.granularities, filters.granularity),
            remove: () => apply({ granularity: null }),
          },
        ]
      : []),
    ...(filters.status
      ? [{ label: labelOf(vocabularies.statuses, filters.status), remove: () => apply({ status: null }) }]
      : []),
  ]

  const facts = (result: CatalogSearchResult) =>
    [
      labelOf(vocabularies.types, result.type),
      result.language,
      result.granularity && labelOf(vocabularies.granularities, result.granularity),
    ].filter((fact): fact is string => Boolean(fact))
  const categoryOf = (result: CatalogSearchResult) =>
    vocabularies.types.find((type) => type.key === result.type)?.category.key ?? 'metadata'

  const pageLink = (target: number) => ({
    href: searchUrl({ ...filters, page: target }),
    only: SEARCH_PROPS,
    preserveState: true,
  })

  return (
    <SiteShell>
      <Container className="pt-10 pb-2 sm:pt-12">
        <PageHeader
          title="Resources"
          count={total}
          description="Every dataset in the library. Search by name or language, and filter by type, script and format."
        />
      </Container>

      <Container className="grid gap-10 py-10 lg:grid-cols-[220px_minmax(0,1fr)]">
        <aside aria-label="Filters" className="hidden flex-col gap-7 lg:flex">
          {facetControls}
        </aside>

        <div className="flex min-w-0 flex-col gap-6">
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <SearchInput
              aria-label="Search resources"
              placeholder="Search by name, language or type…"
              className="min-w-0 flex-1 basis-56"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
            <Drawer>
              <DrawerTrigger asChild>
                <Button variant="outline" className="lg:hidden">
                  <SlidersHorizontalIcon /> Filters{chips.length > 0 && ` · ${chips.length}`}
                </Button>
              </DrawerTrigger>
              <DrawerContent>
                <DrawerHeader>
                  <DrawerTitle>Filters</DrawerTitle>
                  <DrawerDescription className="sr-only">Narrow the resource list</DrawerDescription>
                </DrawerHeader>
                <div className="flex min-h-0 flex-1 flex-col gap-7 overflow-y-auto overscroll-contain px-5 pb-5">
                  {facetControls}
                </div>
                <DrawerFooter>
                  {chips.length > 0 && (
                    <Button variant="outline" onClick={clearAll}>
                      Clear all
                    </Button>
                  )}
                  <DrawerClose asChild>
                    <Button className="flex-1">Show {plural(total, 'result')}</Button>
                  </DrawerClose>
                </DrawerFooter>
              </DrawerContent>
            </Drawer>
            <label className="flex h-9 items-center gap-2 text-sm text-muted-foreground">
              Sort
              <select
                value={filters.sort}
                onChange={(event) => apply({ sort: event.target.value as Filters['sort'] })}
                className="h-9 rounded-lg border bg-card px-2 text-sm text-foreground shadow-xs"
              >
                {vocabularies.sorts.map((sort) => (
                  <option key={sort.key} value={sort.key}>
                    {sort.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          {chips.length > 0 && (
            <div className="flex flex-wrap items-center gap-2" aria-label="Active filters" role="group">
              {chips.map((chip) => (
                <span
                  key={chip.label}
                  className="inline-flex h-7 items-center gap-1 rounded-full border bg-card ps-3 pe-1 text-xs"
                >
                  {chip.label}
                  <button
                    type="button"
                    onClick={chip.remove}
                    aria-label={`Remove ${chip.label}`}
                    className="flex size-5 items-center justify-center rounded-full text-foreground/60 hover:bg-secondary hover:text-foreground"
                  >
                    <XIcon className="size-3" />
                  </button>
                </span>
              ))}
              <button
                type="button"
                onClick={clearAll}
                className="text-xs underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground"
              >
                Clear all
              </button>
            </div>
          )}

          {results.length > 0 ? (
            <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3" aria-label="Resources">
              {results.map((result) => (
                <li key={result.id} className="flex">
                  <ResourceCard
                    className="flex-1"
                    title={result.name}
                    href={detailResources({ type: result.type, id: result.toParam }).url}
                    category={categoryOf(result)}
                    facts={facts(result)}
                    summary={result.summary}
                    status={
                      result.status !== 'stable' && (
                        <StatusBadge status={result.status} label={labelOf(vocabularies.statuses, result.status)} />
                      )
                    }
                    formats={result.formats.map((format) => labelOf(vocabularies.formats, format))}
                    muted={result.status === 'legacy' || result.status === 'superseded'}
                    preview={
                      result.previewKind && (
                        <CardPreview
                          kind={result.previewKind}
                          url={catalogResourcePreview({ type: result.type, slug: result.toParam }).url}
                        />
                      )
                    }
                  />
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState
              title="Nothing matches this search"
              description="Try fewer filters or another word, or tell us what you were looking for."
              action={
                chips.length > 0 && (
                  <Button variant="outline" onClick={clearAll}>
                    Clear all filters
                  </Button>
                )
              }
            />
          )}

          {pages > 1 && (
            <nav aria-label="Pages" className="flex items-center justify-between gap-3 text-sm">
              {page > 1 ? (
                <Button variant="outline" size="sm" asChild>
                  <Link {...pageLink(page - 1)} rel="prev">
                    <ChevronLeftIcon /> Previous
                  </Link>
                </Button>
              ) : (
                <span />
              )}
              <span className="text-muted-foreground tabular-nums">
                Page {page} of {pages}
              </span>
              {page < pages ? (
                <Button variant="outline" size="sm" asChild>
                  <Link {...pageLink(page + 1)} rel="next">
                    Next <ChevronRightIcon />
                  </Link>
                </Button>
              ) : (
                <span />
              )}
            </nav>
          )}

          <RequestCard link={nav.request} />
        </div>
      </Container>
    </SiteShell>
  )
}

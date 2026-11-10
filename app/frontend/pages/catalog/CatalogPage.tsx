import { Link } from '@inertiajs/react'

import { Container, SiteShell } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import { ResourceCard } from '@/components/qul/resource-card'
import { catalogType, detailResources } from '@/routes'
import type { CatalogOption, CatalogResourcesIndex, CatalogSearchResult } from '@/types/serializers'

function label(options: CatalogOption[], key: string | null) {
  return options.find((option) => option.key === key)?.label
}

// /resources: the search results, with links to every type page. The search field, the filters
// and paging arrive with the full catalog page.
export default function CatalogPage({ results, total, vocabularies }: CatalogResourcesIndex) {
  const facts = (result: CatalogSearchResult) =>
    [
      vocabularies.types.find((type) => type.key === result.type)?.label,
      result.language,
      label(vocabularies.granularities, result.granularity),
    ].filter((fact): fact is string => Boolean(fact))

  return (
    <SiteShell>
      <Container className="pt-10 pb-2 sm:pt-12">
        <PageHeader title="Resources" count={total} />
      </Container>

      <Container className="py-10">
        {results.length > 0 ? (
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4" aria-label="Resources">
            {results.map((result) => (
              <li key={result.id} className="flex">
                <ResourceCard
                  className="flex-1"
                  title={result.name}
                  href={detailResources({ type: result.type, id: result.toParam }).url}
                  facts={facts(result)}
                />
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-muted-foreground">No resources match this search.</p>
        )}
      </Container>

      <Container className="pb-12">
        <nav aria-labelledby="resource-types" className="flex flex-col gap-3">
          <h2 id="resource-types" className="text-lg font-medium tracking-tight">
            Resource types
          </h2>
          <ul className="flex flex-wrap gap-2">
            {vocabularies.types.map((type) => (
              <li key={type.key}>
                <Link
                  href={catalogType(type.key).url}
                  className="inline-flex h-8 items-center rounded-md border bg-card px-3 text-sm hover:bg-accent"
                >
                  {type.title}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </Container>
    </SiteShell>
  )
}

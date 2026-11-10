import { Link } from '@inertiajs/react'

import { Container, SiteFrame } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import { ResourceCard } from '@/components/qul/resource-card'
import { cn } from '@/lib/utils'
import { catalogType, detailResources, resources as catalog } from '@/routes'
import type { CatalogResourceCard, CatalogType, CatalogTypesShow } from '@/types/serializers'

function filesLabel(count: number) {
  return count === 1 ? '1 file' : `${count} files`
}

function cardFacts(type: CatalogType, resource: CatalogResourceCard) {
  return [type.label, resource.language, resource.granularity].filter((fact): fact is string => Boolean(fact))
}

// /resources/:type: the type's description and a card for each published resource of the type.
export default function TypePage({ type, types, resources }: CatalogTypesShow) {
  return (
    <SiteFrame>
      <Container className="pt-10 pb-2 sm:pt-12">
        <PageHeader
          breadcrumb={[{ label: 'Resources', href: catalog.index().url }, { label: type.title }]}
          eyebrow={type.category.label === type.title ? undefined : type.category.label}
          title={type.title}
          count={resources.length}
          description={type.description}
        />
      </Container>

      <Container className="py-10">
        {resources.length > 0 ? (
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4" aria-label={type.title}>
            {resources.map((resource) => (
              <li key={resource.id} className="flex">
                <ResourceCard
                  className="flex-1"
                  title={resource.name}
                  href={detailResources({ type: resource.type, id: resource.toParam }).url}
                  facts={cardFacts(type, resource)}
                  footnote={filesLabel(resource.filesCount)}
                />
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-muted-foreground">No resources of this type are published yet.</p>
        )}
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
    </SiteFrame>
  )
}

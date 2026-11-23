import { Link } from '@inertiajs/react'
import { ArrowRightIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { AddToBundle } from '@/components/qul/bundle'
import { CopyButton } from '@/components/qul/copy-button'
import { QulIcon } from '@/components/qul/icons'
import { NavAnchor } from '@/components/qul/nav'
import { PageHeader } from '@/components/qul/page-header'
import { ResultCard } from '@/components/qul/start'
import { Button } from '@/components/ui/button'
import { detailResources } from '@/routes'
import type { StartKitsShow } from '@/types/serializers'

const textLink = 'text-foreground underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground'

function joinAnd(items: string[]) {
  return items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`
}

// /kits/:key: a starter kit (config/kits.yml), from the v8 design (ds/src/app/pages/wizard.tsx,
// Kit). Each item names what it is for, its resource as a card, why it was picked and the
// alternative to swap it for. The kit's guided setup answers open the setup to build your own.
// A resource that is unpublished is left out by the server.
export default function KitPage({
  title,
  description,
  setupPath,
  kitsPath,
  platforms,
  formats,
  items,
  vocabularies,
  catalogPages,
}: StartKitsShow) {
  const badge = [
    `${items.length} ${items.length === 1 ? 'resource' : 'resources'}`,
    joinAnd(platforms),
    formats.join(' or '),
  ].filter(Boolean)

  return (
    <SiteShell>
      <Container className="py-12">
        <PageHeader
          breadcrumb={[{ label: 'Starter kits', href: kitsPath }, { label: title }]}
          eyebrow={
            <span className="inline-flex items-center gap-2 rounded-full border bg-card px-3 py-1 text-xs shadow-xs">
              <QulIcon name="bundle" size={14} /> {badge.join(' · ')}
            </span>
          }
          title={title}
          description={
            <>
              {description} Swap any piece for its alternative, or{' '}
              <Link href={setupPath} className={textLink}>
                build your own from these answers
              </Link>
              .
            </>
          }
          actions={
            <>
              <CopyButton text={() => window.location.href} label="Copy link" />
              <AddToBundle
                ids={items.map((item) => item.resource.id)}
                label="Add kit to bundle"
                addedLabel="Kit is in your bundle"
              />
            </>
          }
        />
      </Container>

      <Container className="grid gap-10 pb-16 lg:grid-cols-[minmax(0,1fr)_320px]">
        <ol aria-label={`In ${title}`} className="flex min-w-0 flex-col gap-6">
          {items.map(({ need, why, resource, alternative }, index) => (
            <li key={resource.id} className="grid grid-cols-1 gap-4 lg:grid-cols-[220px_minmax(0,1fr)]">
              <div className="flex gap-3 lg:pt-2">
                <span className="font-mono text-xs text-muted-foreground">{String(index + 1).padStart(2, '0')}</span>
                <span className="font-medium">{need}</span>
              </div>
              <div className="flex min-w-0 flex-col gap-2">
                <ResultCard result={resource} vocabularies={vocabularies} density="compact" inertia={catalogPages} />
                <p className="text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Why: </span>
                  {why}
                  {alternative && (
                    <>
                      {' '}
                      <NavAnchor
                        link={{
                          href: detailResources({ type: alternative.type, id: alternative.toParam }).url,
                          inertia: catalogPages,
                        }}
                        className={textLink}
                      >
                        Swap for {alternative.name}
                      </NavAnchor>
                    </>
                  )}
                </p>
              </div>
            </li>
          ))}
        </ol>
        <aside className="flex flex-col gap-4 lg:sticky lg:top-20 lg:self-start">
          <div className="flex flex-col items-start gap-3 rounded-xl bg-card p-4 text-sm shadow-xs">
            <p className="font-medium">Not quite your app?</p>
            <p className="text-muted-foreground">
              Start the guided setup from this kit&apos;s answers and change any of them.
            </p>
            <Button variant="outline" size="sm" asChild>
              <Link href={setupPath}>
                Change the answers <ArrowRightIcon />
              </Link>
            </Button>
          </div>
        </aside>
      </Container>
    </SiteShell>
  )
}

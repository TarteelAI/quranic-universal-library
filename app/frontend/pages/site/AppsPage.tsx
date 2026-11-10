import { router } from '@inertiajs/react'
import { ArrowUpRightIcon, CheckIcon, PlusIcon } from 'lucide-react'
import type { ReactNode } from 'react'

import { Container, SiteShell } from '@/components/layout'
import { AppIcon } from '@/components/qul/app-icon'
import { EmptyState } from '@/components/qul/catalog'
import { categoryTile } from '@/components/qul/icons'
import { NavAnchor } from '@/components/qul/nav'
import { PageHeader } from '@/components/qul/page-header'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import { appsDirectory, catalogType } from '@/routes'
import type { CatalogOption, SiteApp, SiteAppsIndex } from '@/types/serializers'

// The props a filter change reloads.
const FILTER_PROPS = ['apps', 'filters']

type Filters = { platform: string | null; type: string | null }

// Each filter change adds a history entry, so Back undoes it.
function filter(filters: Filters) {
  router.get(
    appsDirectory({ query: { platform: filters.platform, type: filters.type } }).url,
    {},
    {
      only: FILTER_PROPS,
      preserveState: true,
      preserveScroll: true,
    },
  )
}

// Where a link goes, in a word: the store, the code host, or the site's own domain.
function linkLabel(url: string) {
  const host = new URL(url).hostname.replace(/^www\./, '')
  const stores: Record<string, string> = {
    'apps.apple.com': 'App Store',
    'play.google.com': 'Google Play',
    'f-droid.org': 'F-Droid',
    'github.com': 'GitHub',
  }
  return stores[host] ?? host
}

// /apps: the apps built with QUL, featured first, with platform and resource type filters in the
// query string. From the v7 design (ds/src/app/pages/apps.tsx), with filters, resource type chips
// that link to the type pages, and the submission issue form in place of the design's dialog.
export default function AppsPage({ apps, total, filters, platforms, types, submitUrl, catalogPages }: SiteAppsIndex) {
  const toggle = (patch: Partial<Filters>) => filter({ ...filters, ...patch })
  const filtered = filters.platform !== null || filters.type !== null

  return (
    <SiteShell>
      <Container className="pt-12 pb-12">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <PageHeader
            title="Apps built with QUL"
            count={total}
            description="Quran readers, study apps, libraries and tools whose makers credit QUL for their data."
          />
          <Button variant="outline" asChild>
            <a href={submitUrl} target="_blank" rel="noreferrer">
              <PlusIcon /> Submit your app
            </a>
          </Button>
        </div>

        <div className="mt-8 flex flex-col gap-3">
          <ChipGroup label="Platform">
            {platforms.map((platform) => (
              <FilterChip
                key={platform.key}
                option={platform}
                selected={filters.platform === platform.key}
                onClick={() => toggle({ platform: filters.platform === platform.key ? null : platform.key })}
              />
            ))}
          </ChipGroup>
          <ChipGroup label="Uses">
            {types.map((type) => (
              <FilterChip
                key={type.key}
                option={type}
                selected={filters.type === type.key}
                onClick={() => toggle({ type: filters.type === type.key ? null : type.key })}
              />
            ))}
          </ChipGroup>
        </div>

        {apps.length > 0 ? (
          <>
            {filtered && (
              <p className="mt-6 text-sm text-muted-foreground" aria-live="polite">
                {apps.length} of {total} apps{' '}
                <button
                  type="button"
                  className="ms-1 text-foreground underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground"
                  onClick={() => filter({ platform: null, type: null })}
                >
                  Show all
                </button>
              </p>
            )}
            <ul aria-label="Apps" className="mt-6 grid gap-x-10 gap-y-3 md:grid-cols-2">
              {apps.map((app) => (
                <AppRow key={app.id} app={app} catalogPages={catalogPages} />
              ))}
            </ul>
          </>
        ) : (
          <EmptyState title="No app matches these filters" className="mt-10" />
        )}

        <p className="mt-12 border-t pt-6 text-sm text-muted-foreground">
          Built something with QUL?{' '}
          <a
            href={submitUrl}
            target="_blank"
            rel="noreferrer"
            className="text-foreground underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground"
          >
            Submit your app
          </a>
          . The QUL team checks each app before it is listed.
        </p>
      </Container>
    </SiteShell>
  )
}

function ChipGroup({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div role="group" aria-label={label} className="flex flex-wrap items-center gap-1.5">
      <span className="w-20 shrink-0 text-sm text-muted-foreground">{label}</span>
      {children}
    </div>
  )
}

function FilterChip({ option, selected, onClick }: { option: CatalogOption; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      className={cn(
        'inline-flex h-8 items-center gap-1.5 rounded-full border bg-card px-3 text-sm transition-colors hover:border-foreground/30 [&_svg]:size-3.5',
        selected && 'border-primary bg-primary text-primary-foreground hover:border-primary',
      )}
    >
      {selected && <CheckIcon />}
      {option.label}
    </button>
  )
}

function AppRow({ app, catalogPages }: { app: SiteApp; catalogPages: boolean }) {
  return (
    <li className="-mx-3 flex items-start gap-4 rounded-xl p-3 transition-colors hover:bg-card">
      <AppIcon app={app} />
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <a href={app.url} target="_blank" rel="noreferrer" className="self-start font-medium hover:underline">
          {app.name}
        </a>
        <p className="text-sm text-pretty text-muted-foreground">{app.description}</p>
        <p className="mt-1 flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
          {app.platforms.join(', ')}
          <span aria-hidden="true">·</span>
          <span className="text-foreground/80">{linkLabel(app.url)}</span>
          <ArrowUpRightIcon className="size-3" aria-hidden="true" />
        </p>
        <ul aria-label={`QUL resources ${app.name} uses`} className="mt-2 flex flex-wrap gap-1.5">
          {app.uses.map((use) => (
            <li key={use.key}>
              <NavAnchor
                link={{ href: catalogType({ type: use.key }).url, inertia: catalogPages }}
                className={cn(
                  'inline-flex h-6 items-center rounded-full px-2.5 text-xs font-medium hover:underline',
                  categoryTile(use.category),
                )}
              >
                {use.label}
              </NavAnchor>
            </li>
          ))}
        </ul>
      </div>
    </li>
  )
}

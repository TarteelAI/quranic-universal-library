import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'
import type { CatalogCategory } from '@/types/serializers'

import { BundleToggle } from './bundle'
import { ResourceIcon } from './icons'
import { NavAnchor } from './nav'

export interface ResourceCardProps {
  title: string
  /** The resource's detail page */
  href: string
  /** Whether a new page serves the detail page (the `catalog` group is on), so the card opens it with an in-app visit */
  inertia?: boolean
  /** The category of the resource's type, which picks the type icon */
  category: CatalogCategory['key']
  /** Short facts, e.g. ["Translation", "Urdu", "Ayah by Ayah"] */
  facts?: string[]
  /** The one-line summary */
  summary?: string | null
  /** Status and recommendation badges, beside the formats */
  status?: ReactNode
  /** Format labels, e.g. ["JSON", "SQLite"] */
  formats?: string[]
  /** A preview fitted to the type (CardPreview), above the text */
  preview?: ReactNode
  /** Legacy and superseded resources: the preview is dimmed */
  muted?: boolean
  /** The resource's id: the card gets the bundle's add and remove toggle */
  bundleId?: number
  /** `compact` is a list row: the type icon, the title, the status and facts, and the formats; no preview or summary */
  density?: 'default' | 'compact'
  className?: string
}

// The browse unit for a downloadable resource, from the v7 design (ds/src/components/qul/cards.tsx).
// With a preview the type icon is small, beside the facts; without one it is a tile beside the
// title. Parts with no data take no space. The whole card is the link (the title link stretches
// over it); the bundle toggle sits above it.
export function ResourceCard({
  title,
  href,
  inertia = true,
  category,
  facts = [],
  summary,
  status,
  formats = [],
  preview,
  muted = false,
  bundleId,
  density = 'default',
  className,
}: ResourceCardProps) {
  const toggle = bundleId !== undefined && <BundleToggle id={bundleId} name={title} />
  const titleLink = (
    <NavAnchor
      link={{ href, inertia }}
      className="outline-none after:absolute after:inset-0 after:rounded-[inherit] focus-visible:underline"
    >
      {title}
    </NavAnchor>
  )

  if (density === 'compact')
    return (
      <article
        className={cn(
          'group relative flex min-w-0 items-center gap-4 rounded-xl bg-card px-4 py-3 shadow-xs transition-shadow hover:shadow-md',
          className,
        )}
        data-testid="resource-card"
      >
        <ResourceIcon category={category} size="md" className={cn(muted && 'grayscale')} />
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-[15px] leading-snug font-medium">{titleLink}</h3>
          {(status || facts.length > 0) && (
            <div className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
              {status}
              {facts.length > 0 && <span className="truncate">{facts.join(' · ')}</span>}
            </div>
          )}
        </div>
        {formats.length > 0 && (
          <span className="hidden font-mono text-[11px] tracking-wide text-muted-foreground uppercase sm:inline">
            {formats.join(' · ')}
          </span>
        )}
        {toggle}
      </article>
    )

  return (
    <article
      className={cn(
        'group relative flex min-w-0 flex-col rounded-xl bg-card shadow-xs transition-shadow hover:shadow-md',
        className,
      )}
      data-testid="resource-card"
    >
      {/* A preview wider than the card (a long line in a font) is cut at the card's edge. */}
      {preview && <div className={cn('overflow-hidden', muted && 'opacity-70 grayscale-50')}>{preview}</div>}
      <div className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex items-start gap-3">
          {!preview && <ResourceIcon category={category} size="md" />}
          <div className="min-w-0 flex-1">
            <h3 className="text-base leading-snug font-medium tracking-tight">{titleLink}</h3>
            {facts.length > 0 && (
              <p className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
                {preview && <ResourceIcon category={category} variant="plain" className="[&_svg]:size-3.5" />}
                {facts.join(' · ')}
              </p>
            )}
          </div>
        </div>
        {summary && <p className="line-clamp-2 text-sm text-muted-foreground">{summary}</p>}
        {(status || formats.length > 0 || toggle) && (
          <div className="mt-auto flex flex-wrap items-center gap-x-3 gap-y-1 pt-1">
            {status}
            {formats.length > 0 && (
              <span className="font-mono text-[11px] tracking-wide text-muted-foreground uppercase">
                {formats.join(' · ')}
              </span>
            )}
            {toggle && <span className="ms-auto">{toggle}</span>}
          </div>
        )}
      </div>
    </article>
  )
}

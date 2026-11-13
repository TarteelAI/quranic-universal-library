import { Link } from '@inertiajs/react'
import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'
import type { CatalogCategory } from '@/types/serializers'

import { ResourceIcon } from './icons'

export interface ResourceCardProps {
  title: string
  /** The resource's detail page, a new page: the card opens it with an in-app visit */
  href: string
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
  className?: string
}

// The browse unit for a downloadable resource, from the v7 design (ds/src/components/qul/cards.tsx).
// The bundle toggle comes with the bundle story. With a preview the type icon is small, beside the
// facts; without one it is a tile beside the title. Parts with no data take no space.
// The whole card is the link (the title link stretches over it). Cards are only shown on catalog
// pages, so the catalog page group is on and a new page serves the detail page they link to.
export function ResourceCard({
  title,
  href,
  category,
  facts = [],
  summary,
  status,
  formats = [],
  preview,
  muted = false,
  className,
}: ResourceCardProps) {
  return (
    <article
      className={cn(
        'group relative flex flex-col rounded-xl bg-card shadow-xs transition-shadow hover:shadow-md',
        className,
      )}
      data-testid="resource-card"
    >
      {preview && <div className={cn(muted && 'opacity-70 grayscale-50')}>{preview}</div>}
      <div className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex items-start gap-3">
          {!preview && <ResourceIcon category={category} size="md" />}
          <div className="min-w-0 flex-1">
            <h3 className="text-base leading-snug font-medium tracking-tight">
              <Link
                href={href}
                className="outline-none after:absolute after:inset-0 after:rounded-[inherit] focus-visible:underline"
              >
                {title}
              </Link>
            </h3>
            {facts.length > 0 && (
              <p className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
                {preview && <ResourceIcon category={category} variant="plain" className="[&_svg]:size-3.5" />}
                {facts.join(' · ')}
              </p>
            )}
          </div>
        </div>
        {summary && <p className="line-clamp-2 text-sm text-muted-foreground">{summary}</p>}
        {(status || formats.length > 0) && (
          <div className="mt-auto flex flex-wrap items-center gap-x-3 gap-y-1 pt-1">
            {status}
            {formats.length > 0 && (
              <span className="font-mono text-[11px] tracking-wide text-muted-foreground uppercase">
                {formats.join(' · ')}
              </span>
            )}
          </div>
        )}
      </div>
    </article>
  )
}

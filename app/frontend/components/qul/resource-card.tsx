import { Link } from '@inertiajs/react'
import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'

export interface ResourceCardProps {
  title: string
  /** The resource's detail page, a new page: the card opens it with an in-app visit */
  href: string
  /** Short facts, e.g. ["Translation", "Urdu", "Ayah by Ayah"] */
  facts?: string[]
  /** Status and recommendation badges, shown above the title */
  badges?: ReactNode
  /** A preview fitted to the type (CardPreview), above the text */
  preview?: ReactNode
  /** Shown at the bottom of the card, e.g. "3 files" */
  footnote?: string
  className?: string
}

// The browse unit for a downloadable resource, from the v7 design (ds/src/components/qul/cards.tsx).
// Formats and the bundle toggle come with the stories that add their data.
// The whole card is the link (the title link stretches over it). Cards are only shown on catalog
// pages, so the catalog page group is on and a new page serves the detail page they link to.
export function ResourceCard({ title, href, facts = [], badges, preview, footnote, className }: ResourceCardProps) {
  return (
    <article
      className={cn(
        'group relative flex flex-col rounded-xl bg-card shadow-xs transition-shadow hover:shadow-md',
        className,
      )}
    >
      {preview}
      <div className="flex flex-1 flex-col gap-3 p-5">
        {badges && <div className="flex flex-wrap items-center gap-x-3 gap-y-1">{badges}</div>}
        <div className="min-w-0">
          <h3 className="text-base leading-snug font-medium tracking-tight">
            <Link
              href={href}
              className="outline-none after:absolute after:inset-0 after:rounded-[inherit] focus-visible:underline"
            >
              {title}
            </Link>
          </h3>
          {facts.length > 0 && <p className="mt-1 text-xs text-muted-foreground">{facts.join(' · ')}</p>}
        </div>
        {footnote && <p className="mt-auto pt-1 font-mono text-[11px] text-muted-foreground">{footnote}</p>}
      </div>
    </article>
  )
}

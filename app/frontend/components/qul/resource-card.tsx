import { cn } from '@/lib/utils'

export interface ResourceCardProps {
  title: string
  href: string
  /** Short facts, e.g. ["Translation", "Urdu", "Ayah by Ayah"] */
  facts?: string[]
  /** Shown at the bottom of the card, e.g. "3 files" */
  footnote?: string
  className?: string
}

// The browse unit for a downloadable resource, from the v7 design (ds/src/components/qul/cards.tsx).
// Status, formats, previews and the bundle toggle come with the stories that add their data.
// The whole card is the link (the title link stretches over it).
export function ResourceCard({ title, href, facts = [], footnote, className }: ResourceCardProps) {
  return (
    <article
      className={cn(
        'group relative flex flex-col rounded-xl bg-card shadow-xs transition-shadow hover:shadow-md',
        className,
      )}
    >
      <div className="flex flex-1 flex-col gap-3 p-5">
        <div className="min-w-0">
          <h3 className="text-base leading-snug font-medium tracking-tight">
            <a
              href={href}
              className="outline-none after:absolute after:inset-0 after:rounded-[inherit] focus-visible:underline"
            >
              {title}
            </a>
          </h3>
          {facts.length > 0 && <p className="mt-1 text-xs text-muted-foreground">{facts.join(' · ')}</p>}
        </div>
        {footnote && <p className="mt-auto pt-1 font-mono text-[11px] text-muted-foreground">{footnote}</p>}
      </div>
    </article>
  )
}

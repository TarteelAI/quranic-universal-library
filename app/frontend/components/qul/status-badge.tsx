import { ArrowRightIcon } from 'lucide-react'

import { cn } from '@/lib/utils'

type Status = 'stable' | 'beta' | 'legacy' | 'superseded'

const STATUS_DOT: Record<Status, string> = {
  stable: 'bg-foreground/40',
  beta: 'bg-cat-layout',
  legacy: 'bg-cat-linguistics',
  superseded: 'bg-cat-script',
}

export interface StatusBadgeProps {
  status: Status
  /** The status label from the server's vocabulary */
  label: string
  /** For `superseded`: a link to the replacement */
  supersededBy?: { name: string; href: string } | null
  className?: string
}

// Lifecycle status as a small dot and label, from the v7 design (ds/src/components/qul/badges.tsx).
// The replacement link sits above a card's stretched link, so it stays clickable inside a card.
export function StatusBadge({ status, label, supersededBy, className }: StatusBadgeProps) {
  return (
    <span className={cn('inline-flex w-fit flex-wrap items-center gap-1.5 text-xs text-muted-foreground', className)}>
      <span className={cn('size-2 shrink-0 rounded-full', STATUS_DOT[status])} aria-hidden="true" />
      <span>{label}</span>
      {status === 'superseded' && supersededBy && (
        <a
          href={supersededBy.href}
          aria-label={`Replaced by ${supersededBy.name}`}
          className="relative z-10 inline-flex items-center gap-0.5 text-foreground underline-offset-2 hover:underline"
        >
          <ArrowRightIcon className="size-3" aria-hidden="true" />
          {supersededBy.name}
        </a>
      )}
    </span>
  )
}

export interface RecommendedBadgeProps {
  className?: string
}

export function RecommendedBadge({ className }: RecommendedBadgeProps) {
  return (
    <span className={cn('inline-flex w-fit items-center gap-1.5 text-xs font-medium text-foreground', className)}>
      <span className="size-2 shrink-0 rounded-full bg-brand" aria-hidden="true" />
      Recommended
    </span>
  )
}

import { ArrowUpRightIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/misc'
import { cn } from '@/lib/utils'
import type { CatalogCategory, SiteNavLink } from '@/types/serializers'

import { QulIcon, ResourceIcon, type IconName } from './icons'

/* ---------------- FacetGroup ---------------- */

export interface FacetOption {
  value: string
  label: string
  count: number
  checked: boolean
  /** Shows the category icon before the label (resource types) */
  category?: CatalogCategory['key']
}

export interface FacetGroupProps {
  title: string
  options: FacetOption[]
  onToggle: (value: string) => void
  /** Shows this many options and a button for the rest; checked options always show. */
  limit?: number
  className?: string
}

/** One section of the catalog filter rail: a checkbox per value, with its result count. */
function FacetGroup({ title, options, onToggle, limit, className }: FacetGroupProps) {
  const [expanded, setExpanded] = React.useState(false)
  const hidden = limit && !expanded ? options.slice(limit).filter((option) => !option.checked) : []
  const shown = options.filter((option) => !hidden.includes(option))

  return (
    <fieldset className={cn('flex flex-col gap-1', className)}>
      <legend className="mb-2 text-sm font-medium">{title}</legend>
      {shown.map((option) => (
        <label
          key={option.value}
          className="flex cursor-pointer items-center gap-2.5 rounded-md px-2 py-1.5 text-sm hover:bg-secondary"
        >
          <Checkbox checked={option.checked} onCheckedChange={() => onToggle(option.value)} />
          {option.category && (
            <ResourceIcon category={option.category} variant="plain" size="sm" className="[&_svg]:size-4" />
          )}
          <span className="min-w-0 flex-1 truncate">{option.label}</span>
          <span className="font-mono text-xs text-muted-foreground tabular-nums">{option.count}</span>
        </label>
      ))}
      {hidden.length > 0 && (
        <button
          type="button"
          onClick={() => setExpanded(true)}
          className="w-fit px-2 py-1 text-xs text-muted-foreground underline decoration-foreground/30 underline-offset-4 hover:text-foreground"
        >
          Show {hidden.length} more
        </button>
      )}
    </fieldset>
  )
}

/* ---------------- EmptyState / RequestCard ---------------- */

export interface EmptyStateProps {
  icon?: IconName
  title: string
  description?: string
  action?: React.ReactNode
  className?: string
}

function EmptyState({ icon = 'research', title, description, action, className }: EmptyStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center gap-4 rounded-xl border border-dashed bg-card px-6 py-12 text-center',
        className,
      )}
    >
      <span className="flex size-12 items-center justify-center rounded-lg bg-secondary">
        <QulIcon name={icon} size={24} />
      </span>
      <div>
        <p className="text-lg font-medium tracking-tight">{title}</p>
        {description && <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">{description}</p>}
      </div>
      {action}
    </div>
  )
}

export interface RequestCardProps {
  /** The resource request form (the `nav.request` shared prop) */
  link: Pick<SiteNavLink, 'href' | 'label'>
  className?: string
}

/** "Can't find it? Request it." at the end of a list and in empty states: links to the issue form. */
function RequestCard({ link, className }: RequestCardProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-start gap-4 rounded-xl bg-card p-5 shadow-xs sm:flex-row sm:items-center sm:p-6',
        className,
      )}
    >
      <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
        <QulIcon name="request" size={20} />
      </span>
      <div className="flex-1">
        <p className="font-medium">Can't find what you need?</p>
        <p className="text-sm text-muted-foreground">Tell us what's missing on GitHub.</p>
      </div>
      <Button variant="outline" asChild>
        <a href={link.href} target="_blank" rel="noreferrer">
          {link.label} <ArrowUpRightIcon />
        </a>
      </Button>
    </div>
  )
}

export { FacetGroup, EmptyState, RequestCard }

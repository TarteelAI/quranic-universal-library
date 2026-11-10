import { Fragment, type ReactNode } from 'react'

import { cn } from '@/lib/utils'

export interface PageHeaderProps {
  /** Breadcrumb trail; the last item is the current page */
  breadcrumb?: { label: string; href?: string }[]
  eyebrow?: ReactNode
  title: ReactNode
  /** Resource count, shown small and muted after the title */
  count?: number
  description?: ReactNode
  className?: string
}

// From the v7 design (ds/src/components/qul/chrome.tsx), without the icon and actions slots.
export function PageHeader({ breadcrumb, eyebrow, title, count, description, className }: PageHeaderProps) {
  return (
    <div className={cn('flex flex-col gap-4', className)}>
      {breadcrumb && (
        <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-muted-foreground">
          {breadcrumb.map((item, index) => (
            <Fragment key={item.label}>
              {index > 0 && <span aria-hidden="true">›</span>}
              {item.href ? (
                <a href={item.href} className="hover:text-foreground">
                  {item.label}
                </a>
              ) : (
                <span className="text-foreground">{item.label}</span>
              )}
            </Fragment>
          ))}
        </nav>
      )}
      <div className="flex flex-col gap-2">
        {eyebrow && <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">{eyebrow}</div>}
        <h1 className="headline text-3xl sm:text-4xl">
          {title}
          {count !== undefined && (
            <span className="ms-3 align-middle font-mono text-sm font-normal tracking-normal text-muted-foreground tabular-nums">
              {count}
            </span>
          )}
        </h1>
        {description && <p className="max-w-2xl text-base text-pretty text-muted-foreground">{description}</p>}
      </div>
    </div>
  )
}

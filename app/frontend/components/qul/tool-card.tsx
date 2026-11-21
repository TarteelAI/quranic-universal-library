import { ArrowUpRightIcon } from 'lucide-react'

import { categoryTile } from '@/components/qul/icons'
import { navIcon } from '@/components/qul/nav'
import { cn } from '@/lib/utils'
import type { SiteNavLink } from '@/types/serializers'

function toolIcon(name: NonNullable<SiteNavLink['icon']>) {
  const Icon = navIcon(name)
  return <Icon aria-hidden className="size-5" />
}

/**
 * A contribution tool: a plain link to its old page, which checks access itself. A tool with a
 * category has its icon in that category's colour.
 */
function ToolCard({ tool }: { tool: SiteNavLink }) {
  return (
    <a
      href={tool.href}
      className="group flex h-full gap-4 rounded-xl border bg-card p-5 transition-shadow hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
    >
      <span
        className={cn(
          'flex size-10 shrink-0 items-center justify-center rounded-lg',
          tool.category ? categoryTile(tool.category) : 'bg-secondary text-foreground',
        )}
      >
        {tool.icon && toolIcon(tool.icon)}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{tool.label}</span>
        {tool.description && <span className="mt-0.5 block text-sm text-muted-foreground">{tool.description}</span>}
      </span>
      <ArrowUpRightIcon
        aria-hidden
        className="mt-1 size-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-foreground"
      />
    </a>
  )
}

export { ToolCard }

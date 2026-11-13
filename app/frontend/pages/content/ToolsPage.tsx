import { Link } from '@inertiajs/react'
import { ArrowUpRightIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { navIcon } from '@/components/qul/nav'
import { PageHeader } from '@/components/qul/page-header'
import { Button } from '@/components/ui/button'
import { docsPage } from '@/routes'
import type { ContentPagesTools, SiteNavLink } from '@/types/serializers'

function toolIcon(name: NonNullable<SiteNavLink['icon']>) {
  const Icon = navIcon(name)
  return <Icon aria-hidden className="size-5" />
}

// A contribution tool: a plain link to its old page, which checks access itself.
function ToolCard({ tool }: { tool: SiteNavLink }) {
  return (
    <a
      href={tool.href}
      className="group flex h-full gap-4 rounded-xl border bg-card p-5 transition-shadow hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
    >
      <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary text-foreground">
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

// /tools: the contribution tools (ToolsHelper#developer_tools) in the Contribute menu's groups
// (SiteNav::ContributeTools). From the v8 design (ds/src/app/pages/more.tsx), without access
// state or progress.
export default function ToolsPage({ groups }: ContentPagesTools) {
  return (
    <SiteShell>
      <Container className="pt-12 pb-2">
        <PageHeader
          title="Contribution tools"
          description="Volunteers check and fix QUL data with these tools. Each fix reaches every app that uses the data. Some tools need editing access: open the tool to ask for it."
          actions={
            <Button variant="outline" asChild>
              <Link href={docsPage('contribute-data').url}>How to contribute data</Link>
            </Button>
          }
        />
      </Container>
      <Container className="flex flex-col gap-12 py-12">
        {groups.map((group) => (
          <section key={group.heading} aria-label={group.heading} className="grid gap-6 lg:grid-cols-[240px_1fr]">
            <div>
              <h2 className="headline text-2xl">{group.heading}</h2>
              {group.summary && <p className="mt-1 text-sm text-muted-foreground">{group.summary}</p>}
            </div>
            <ul className="grid gap-3 md:grid-cols-2">
              {group.tools.map((tool) => (
                <li key={tool.href}>
                  <ToolCard tool={tool} />
                </li>
              ))}
            </ul>
          </section>
        ))}
      </Container>
    </SiteShell>
  )
}

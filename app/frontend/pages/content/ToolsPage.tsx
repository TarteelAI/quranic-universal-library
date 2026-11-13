import { Link } from '@inertiajs/react'

import { Container, SiteShell } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import { ToolCard } from '@/components/qul/tool-card'
import { Button } from '@/components/ui/button'
import { docsPage } from '@/routes'
import type { ContentPagesTools } from '@/types/serializers'

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

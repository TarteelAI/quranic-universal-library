import { Link } from '@inertiajs/react'
import { ArrowRightIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { KitCard } from '@/components/qul/start'
import { PageHeader } from '@/components/qul/page-header'
import { Button } from '@/components/ui/button'
import { startSetup } from '@/routes'
import type { StartKitsIndex } from '@/types/serializers'

// /kits: every starter kit (config/kits.yml) as the card of the home page's "Start from a kit"
// row. The prototype has no design for this page.
export default function KitsPage({ kits }: StartKitsIndex) {
  return (
    <SiteShell>
      <Container className="flex flex-col gap-10 py-12">
        <PageHeader
          title="Starter kits"
          count={kits.length}
          description="Curated sets of resources that work together for one kind of app, with the reason for each pick."
          actions={
            <Button variant="outline" asChild>
              <Link href={startSetup.show().url}>
                Build your own <ArrowRightIcon />
              </Link>
            </Button>
          }
        />
        <ul className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {kits.map((kit) => (
            <li key={kit.key}>
              <KitCard kit={kit} />
            </li>
          ))}
        </ul>
      </Container>
    </SiteShell>
  )
}

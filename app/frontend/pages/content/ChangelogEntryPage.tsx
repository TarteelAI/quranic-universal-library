import { Container, SiteShell } from '@/components/layout'
import { ChangelogResource } from '@/components/qul/changelog'
import { PageHeader } from '@/components/qul/page-header'
import { changelogPage } from '@/routes'
import type { ContentChangelogShow } from '@/types/serializers'

// /changelog/:id: one published changelog entry, its date, its resource and its body (editor
// HTML the server reduced to prose).
export default function ChangelogEntryPage({ entry }: ContentChangelogShow) {
  return (
    <SiteShell>
      <Container className="max-w-3xl pt-12 pb-16">
        <PageHeader
          breadcrumb={[{ label: 'Changelog', href: changelogPage().url }, { label: entry.title }]}
          title={entry.title}
          eyebrow={<time>{entry.date}</time>}
          description={
            entry.resource && (
              <>
                Resource: <ChangelogResource resource={entry.resource} />
              </>
            )
          }
        />
        <article className="docs-prose mt-10" dangerouslySetInnerHTML={{ __html: entry.body }} />
      </Container>
    </SiteShell>
  )
}

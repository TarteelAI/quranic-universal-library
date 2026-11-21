import { Link } from '@inertiajs/react'
import { ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { ChangelogResource } from '@/components/qul/changelog'
import { PageHeader } from '@/components/qul/page-header'
import { Button } from '@/components/ui/button'
import { changelogPage } from '@/routes'
import type { ContentChangelogIndex } from '@/types/serializers'

const pageUrl = (page: number) => changelogPage(page > 1 ? { query: { page } } : undefined).url

// /changelog: the published changelog entries, newest first, a page at a time (?page=).
export default function ChangelogPage({ entries, page, pages }: ContentChangelogIndex) {
  return (
    <SiteShell>
      <Container className="max-w-4xl pt-12 pb-16">
        <PageHeader
          title="Changelog"
          description="Updates and fixes to QUL resources, newest first. Each entry names the resource it changed."
        />

        {entries.length > 0 ? (
          <ol aria-label="Changelog" className="mt-10 divide-y border-y">
            {entries.map((entry) => (
              <li key={entry.id} className="flex flex-col gap-1.5 py-5 sm:flex-row sm:gap-6">
                <span className="shrink-0 text-sm text-muted-foreground tabular-nums sm:w-36 sm:pt-0.5">
                  {entry.date}
                </span>
                <div className="flex min-w-0 flex-col gap-1.5">
                  <Link href={entry.path} className="text-lg font-medium tracking-tight hover:underline">
                    {entry.title}
                  </Link>
                  <p className="text-muted-foreground">{entry.excerpt}</p>
                  {entry.resource && (
                    <p className="text-sm text-muted-foreground">
                      Resource: <ChangelogResource resource={entry.resource} />
                    </p>
                  )}
                </div>
              </li>
            ))}
          </ol>
        ) : (
          <p className="mt-10 rounded-xl border p-6 text-muted-foreground">No changes are published yet.</p>
        )}

        {pages > 1 && (
          <nav aria-label="Pages" className="mt-8 flex items-center justify-between gap-3 text-sm">
            {page > 1 ? (
              <Button variant="outline" size="sm" asChild>
                <Link href={pageUrl(page - 1)} rel="prev">
                  <ChevronLeftIcon /> Newer
                </Link>
              </Button>
            ) : (
              <span />
            )}
            <span className="text-muted-foreground tabular-nums">
              Page {page} of {pages}
            </span>
            {page < pages ? (
              <Button variant="outline" size="sm" asChild>
                <Link href={pageUrl(page + 1)} rel="next">
                  Older <ChevronRightIcon />
                </Link>
              </Button>
            ) : (
              <span />
            )}
          </nav>
        )}
      </Container>
    </SiteShell>
  )
}

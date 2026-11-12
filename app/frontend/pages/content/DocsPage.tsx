import { Link } from '@inertiajs/react'
import { ArrowLeftIcon, ArrowRightIcon } from 'lucide-react'

import { Container, SiteShell } from '@/components/layout'
import { DocBody, DocContents } from '@/components/qul/docs'
import { cn } from '@/lib/utils'
import { docsIndex, docsPage } from '@/routes'
import type { ContentDocLink, ContentDocsShow } from '@/types/serializers'

// /docs/:key: a docs page from the markdown in app/views/docs/markdown, or a resource tag page.
// The body and the contents list come from the server (Content::DocPage). Story 002-05 adds the
// v8 docs layout around it (side navigation, phone layout); this page has the breadcrumb, the
// contents list and the previous and next pages.
export default function DocsPage({ doc }: ContentDocsShow) {
  const { category, previous, next } = doc.position

  return (
    <SiteShell>
      <Container className="pt-10 pb-16">
        <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-muted-foreground">
          <a href={docsIndex().url} className="hover:text-foreground">
            Docs
          </a>
          {category && (
            <>
              <span aria-hidden="true">›</span>
              <Link href={docsPage(category.key).url} className="hover:text-foreground">
                {category.title}
              </Link>
            </>
          )}
        </nav>

        <div className="mt-6 grid gap-10 lg:grid-cols-[minmax(0,1fr)_14rem]">
          <div className="min-w-0">
            {/* A tag page's body has no h1 (as on the old page), so the title is here. */}
            {doc.kind === 'tag' && <h1 className="headline mb-6 text-3xl sm:text-4xl">{doc.title}</h1>}
            <article>
              <DocBody segments={doc.segments} />
            </article>
            {(previous || next) && (
              <nav aria-label="Previous and next pages" className="mt-12 grid gap-3 sm:grid-cols-2">
                {previous && <PageLink link={previous} direction="previous" />}
                {next && <PageLink link={next} direction="next" />}
              </nav>
            )}
          </div>
          <aside className="hidden lg:block">
            <DocContents contents={doc.contents} className="sticky top-24" />
          </aside>
        </div>
      </Container>
    </SiteShell>
  )
}

function PageLink({ link, direction }: { link: ContentDocLink; direction: 'previous' | 'next' }) {
  const isNext = direction === 'next'
  return (
    <Link
      href={docsPage(link.key).url}
      className={cn(
        'flex flex-col gap-1 rounded-lg border border-border p-4 hover:bg-accent',
        isNext && 'items-end text-end sm:col-start-2',
      )}
    >
      <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
        {isNext ? (
          <>
            Next <ArrowRightIcon className="size-3" />
          </>
        ) : (
          <>
            <ArrowLeftIcon className="size-3" /> Previous
          </>
        )}
      </span>
      <span className="font-medium">{link.title}</span>
    </Link>
  )
}

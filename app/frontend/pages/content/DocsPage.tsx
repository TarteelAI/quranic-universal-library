import { Link } from '@inertiajs/react'
import { ArrowLeftIcon, ArrowRightIcon } from 'lucide-react'

import { SiteShell } from '@/components/layout'
import { DocBody, DocsLayout } from '@/components/qul/docs'
import { cn } from '@/lib/utils'
import { docsIndexPage, docsPage } from '@/routes'
import type { ContentDocLink, ContentDocsShow } from '@/types/serializers'

// /docs/:key: a docs page from the markdown in app/views/docs/markdown, or a resource tag page,
// in the docs layout. The body and the contents list come from the server (Content::DocPage).
export default function DocsPage({ doc, navigation }: ContentDocsShow) {
  const { category, previous, next } = doc.position

  return (
    <SiteShell>
      <DocsLayout
        navigation={navigation}
        current={doc.key}
        trail={[...(category ? [category.title] : []), doc.title]}
        contents={doc.contents}
      >
        <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-muted-foreground">
          <Link href={docsIndexPage().url} className="hover:text-foreground">
            Docs
          </Link>
          {category && (
            <>
              <span aria-hidden="true">›</span>
              <Link href={docsPage(category.key).url} className="hover:text-foreground">
                {category.title}
              </Link>
            </>
          )}
        </nav>

        <div className="mt-6">
          {/* A tag page's body has no h1 (as on the old page), so the title is here. */}
          {doc.kind === 'tag' && <h1 className="headline mb-6 text-3xl sm:text-4xl">{doc.title}</h1>}
          <article>
            <DocBody segments={doc.segments} />
          </article>
          {(previous || next) && (
            <nav aria-label="Previous and next pages" className="mt-16 grid gap-3 border-t pt-6 sm:grid-cols-2">
              {previous && <PageLink link={previous} direction="previous" />}
              {next && <PageLink link={next} direction="next" />}
            </nav>
          )}
        </div>
      </DocsLayout>
    </SiteShell>
  )
}

function PageLink({ link, direction }: { link: ContentDocLink; direction: 'previous' | 'next' }) {
  const isNext = direction === 'next'
  return (
    <Link
      href={docsPage(link.key).url}
      rel={direction === 'previous' ? 'prev' : 'next'}
      className={cn(
        'group flex flex-col gap-1 rounded-xl border px-4 py-3.5 transition-colors hover:border-foreground/25',
        isNext && 'items-end text-end sm:col-start-2',
      )}
    >
      <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
        {isNext ? (
          <>
            Next <ArrowRightIcon className="size-3.5" />
          </>
        ) : (
          <>
            <ArrowLeftIcon className="size-3.5" /> Previous
          </>
        )}
      </span>
      <span className="font-medium">{link.title}</span>
    </Link>
  )
}

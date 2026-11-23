import { Link } from '@inertiajs/react'
import { ArrowRightIcon } from 'lucide-react'

import { SiteShell } from '@/components/layout'
import { DocsLayout } from '@/components/qul/docs'
import { Badge } from '@/components/ui/badge'
import { docsPage } from '@/routes'
import type { ContentDocsIndex } from '@/types/serializers'

// /docs: the docs index, one card per category of config/docs.yml with its pages.
export default function DocsIndexPage({ navigation }: ContentDocsIndex) {
  return (
    <SiteShell>
      <DocsLayout navigation={navigation} current={null} trail={['All docs']}>
        <header className="flex max-w-2xl flex-col gap-4">
          <h1 className="headline text-4xl sm:text-5xl">QUL documentation</h1>
          <p className="text-lg leading-relaxed text-muted-foreground">
            How to download QUL resources and use them in your app, and how to contribute code and data back to the
            project.
          </p>
        </header>

        <ul className="mt-10 grid gap-4 sm:grid-cols-2">
          {navigation.map((category) => {
            // The first page of a category is its overview, which the card's title opens.
            const pages = category.pages.filter((page) => page.depth === 0 && page.key !== category.key)
            return (
              <li key={category.key} className="flex flex-col gap-4 rounded-2xl border bg-card p-5">
                <div className="flex flex-col gap-1.5">
                  <h2 className="flex flex-wrap items-center gap-2 text-lg font-medium tracking-tight">
                    <Link href={docsPage(category.key).url} className="hover:underline">
                      {category.title}
                    </Link>
                    {category.badge && <Badge variant="warning">{category.badge}</Badge>}
                  </h2>
                  {category.description && <p className="text-sm text-muted-foreground">{category.description}</p>}
                </div>
                {pages.length > 0 && (
                  <ul className="flex flex-col border-t pt-3 text-sm">
                    {pages.map((page) => (
                      <li key={page.key}>
                        <Link
                          href={docsPage(page.key).url}
                          className="group flex items-center justify-between gap-2 py-1.5 hover:text-foreground"
                        >
                          {page.title}
                          <ArrowRightIcon className="size-3.5 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
                        </Link>
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            )
          })}
        </ul>
      </DocsLayout>
    </SiteShell>
  )
}

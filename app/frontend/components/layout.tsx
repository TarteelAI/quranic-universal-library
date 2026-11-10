import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'
import { resources, root } from '@/routes'

// The minimal frame of the new pages: a home link and a link to the catalog. The v7 header
// and footer replace it in story 001-11. Both links go to old pages, so they are plain links.
export function SiteFrame({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="border-b bg-card">
        <Container className="flex h-14 items-center justify-between gap-4">
          <a href={root().url} className="font-medium tracking-tight">
            Quranic Universal Library
          </a>
          <nav aria-label="Main">
            <a href={resources.index().url} className="text-sm text-muted-foreground hover:text-foreground">
              Resources
            </a>
          </nav>
        </Container>
      </header>
      <main className="flex-1">{children}</main>
      <footer className="border-t">
        <Container className="py-6 text-sm text-muted-foreground">
          QUL is a project of{' '}
          <a href="https://tarteel.ai" className="underline hover:text-foreground">
            Tarteel AI
          </a>
          .
        </Container>
      </footer>
    </div>
  )
}

export function Container({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn('mx-auto w-full max-w-7xl px-4 sm:px-6', className)}>{children}</div>
}

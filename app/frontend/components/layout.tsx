import type { ReactNode } from 'react'

import { SiteFooter, SiteHeader } from '@/components/qul/chrome'
import { FlashMessages } from '@/components/qul/flash'
import { cn } from '@/lib/utils'

// The frame of every new page: the v7 header, the flash messages, the page and the footer.
export function SiteShell({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <FlashMessages />
      <main className="flex-1">{children}</main>
      <SiteFooter />
    </div>
  )
}

export function Container({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn('mx-auto w-full max-w-7xl px-4 sm:px-6', className)}>{children}</div>
}

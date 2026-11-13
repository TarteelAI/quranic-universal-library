import type { ReactNode } from 'react'

import { SiteFooter, SiteHeader } from '@/components/qul/chrome'
import { FlashMessages } from '@/components/qul/flash'
import { RequestDialogProvider } from '@/components/qul/request-dialog'
import { cn } from '@/lib/utils'

// The frame of every new page: the v7 header, the flash messages, the page and the footer, and
// the request dialog the page can open.
export function SiteShell({ children }: { children: ReactNode }) {
  return (
    <RequestDialogProvider>
      <div className="flex min-h-screen flex-col">
        <SiteHeader />
        <FlashMessages />
        <main className="flex-1">{children}</main>
        <SiteFooter />
      </div>
    </RequestDialogProvider>
  )
}

export function Container({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn('mx-auto w-full max-w-7xl px-4 sm:px-6', className)}>{children}</div>
}

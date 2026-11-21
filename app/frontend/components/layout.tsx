import type { ReactNode } from 'react'

import { SiteFooter, SiteHeader } from '@/components/qul/chrome'
import { RequestDialogProvider } from '@/components/qul/request-dialog'
import { Toaster } from '@/components/ui/sonner'
import { useFlashToasts } from '@/lib/flash'
import { cn } from '@/lib/utils'

// The frame of every new page: the v7 header, the page and the footer, the request dialog the
// page can open, and the toasts, which show the flash messages.
export function SiteShell({ children }: { children: ReactNode }) {
  useFlashToasts()

  return (
    <RequestDialogProvider>
      <div className="flex min-h-screen flex-col">
        <SiteHeader />
        {/* Focusable from code only: the bundle tray hands the focus here when its button is gone. */}
        <main tabIndex={-1} className="flex-1 outline-none">
          {children}
        </main>
        <SiteFooter />
      </div>
      <Toaster />
    </RequestDialogProvider>
  )
}

export function Container({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn('mx-auto w-full max-w-7xl px-4 sm:px-6', className)}>{children}</div>
}

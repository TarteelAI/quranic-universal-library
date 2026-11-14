import { usePage } from '@inertiajs/react'
import { CircleAlertIcon, CircleCheckIcon, XIcon } from 'lucide-react'
import * as React from 'react'

import { cn } from '@/lib/utils'

/**
 * The Rails flash (`notice` and `alert`) of the current page. It shows on the page the
 * redirect lands on and is gone after the next visit; the close button hides it sooner.
 */
function FlashMessages({ className }: { className?: string }) {
  const { flash } = usePage()
  const [hidden, setHidden] = React.useState<typeof flash | null>(null)
  if (hidden === flash || !(flash.notice || flash.alert)) return null

  return (
    <div className={cn('mx-auto flex w-full max-w-7xl flex-col gap-2 px-4 pt-4 sm:px-6', className)}>
      {flash.notice && (
        <Message role="status" onClose={() => setHidden(flash)}>
          <CircleCheckIcon className="text-success" />
          {flash.notice}
        </Message>
      )}
      {flash.alert && (
        <Message role="alert" onClose={() => setHidden(flash)}>
          <CircleAlertIcon className="text-error" />
          {flash.alert}
        </Message>
      )}
    </div>
  )
}

function Message({
  role,
  onClose,
  children,
}: {
  role: 'status' | 'alert'
  onClose: () => void
  children: React.ReactNode
}) {
  return (
    <div
      role={role}
      className="flex items-center gap-3 rounded-xl bg-card px-4 py-3 text-sm shadow-xs [&>svg]:size-4 [&>svg]:shrink-0"
    >
      {children}
      <button
        type="button"
        onClick={onClose}
        aria-label="Close the message"
        className="ms-auto flex size-7 items-center justify-center rounded-full text-muted-foreground hover:bg-secondary hover:text-foreground"
      >
        <XIcon className="size-3.5" />
      </button>
    </div>
  )
}

export { FlashMessages }

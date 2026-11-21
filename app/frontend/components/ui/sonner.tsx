import { CircleAlertIcon, CircleCheckIcon } from 'lucide-react'
import * as React from 'react'
import { Toaster as Sonner, toast, type ToasterProps } from 'sonner'

import { useTheme } from '@/lib/theme'

// Below the sticky header (64px) with a gap, so a toast never covers it.
const TOP_OFFSET = { top: 76 }

// Where toasts show: top centre, over the page, so a message moves no content. Call `toast`
// from `sonner` to show one. Sonner's own styles are not in a CSS layer, so the tokens go in as
// its variables, not as classes.
function Toaster(props: ToasterProps) {
  const theme = useTheme()

  // Sonner replays the toasts still open to a Toaster that mounts, and each Inertia visit mounts
  // the page shell again: a toast left open would show again, for its full time, on every page.
  React.useEffect(() => () => void toast.dismiss(), [])

  return (
    <Sonner
      theme={theme ?? 'light'}
      position="top-center"
      offset={TOP_OFFSET}
      mobileOffset={TOP_OFFSET}
      icons={{
        success: <CircleCheckIcon className="size-4 text-success" />,
        error: <CircleAlertIcon className="size-4 text-error" />,
      }}
      style={
        {
          '--normal-bg': 'var(--popover)',
          '--normal-text': 'var(--popover-foreground)',
          '--normal-border': 'var(--border)',
          '--border-radius': 'calc(var(--radius) + 4px)',
          fontFamily: 'inherit',
        } as React.CSSProperties
      }
      {...props}
    />
  )
}

export { Toaster }

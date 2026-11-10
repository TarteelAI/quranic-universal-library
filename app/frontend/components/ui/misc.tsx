import * as React from 'react'
import { Checkbox as CheckboxPrimitive, Separator as SeparatorPrimitive } from 'radix-ui'
import { CheckIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

function Separator({
  className,
  orientation = 'horizontal',
  decorative = true,
  ...props
}: React.ComponentProps<typeof SeparatorPrimitive.Root>) {
  return (
    <SeparatorPrimitive.Root
      data-slot="separator"
      decorative={decorative}
      orientation={orientation}
      className={cn(
        'shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px',
        className,
      )}
      {...props}
    />
  )
}

function Skeleton({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="skeleton" className={cn('animate-pulse rounded-xl bg-muted', className)} {...props} />
}

function Checkbox({ className, ...props }: React.ComponentProps<typeof CheckboxPrimitive.Root>) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        'peer size-[18px] shrink-0 rounded-[6px] border-[1.5px] border-foreground/30 bg-card outline-none transition-shadow focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:opacity-50 data-[state=checked]:border-foreground data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground',
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator className="flex items-center justify-center text-current">
        <CheckIcon className="size-3.5" strokeWidth={3} />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

/** A single keycap, e.g. the ⌘K hint inside the search field. */
function Kbd({ className, ...props }: React.ComponentProps<'kbd'>) {
  return (
    <kbd
      data-slot="kbd"
      className={cn(
        'pointer-events-none inline-flex h-5 min-w-5 select-none items-center justify-center gap-1 rounded-md border bg-card px-1.5 font-mono text-[11px] font-medium text-muted-foreground',
        className,
      )}
      {...props}
    />
  )
}

function Table({ className, ...props }: React.ComponentProps<'table'>) {
  return (
    <div data-slot="table-container" className="relative w-full overflow-x-auto">
      <table data-slot="table" className={cn('w-full caption-bottom text-sm', className)} {...props} />
    </div>
  )
}
function TableHeader({ className, ...props }: React.ComponentProps<'thead'>) {
  return <thead className={cn('[&_tr]:border-b', className)} {...props} />
}
function TableBody({ className, ...props }: React.ComponentProps<'tbody'>) {
  return <tbody className={cn('[&_tr:last-child]:border-0', className)} {...props} />
}
function TableRow({ className, ...props }: React.ComponentProps<'tr'>) {
  return <tr className={cn('border-b transition-colors hover:bg-accent', className)} {...props} />
}
function TableHead({ className, ...props }: React.ComponentProps<'th'>) {
  return (
    <th
      className={cn(
        'h-9 whitespace-nowrap px-3 text-left align-middle text-xs font-medium text-muted-foreground',
        className,
      )}
      {...props}
    />
  )
}
function TableCell({ className, ...props }: React.ComponentProps<'td'>) {
  return <td className={cn('whitespace-nowrap px-3 py-2 align-middle', className)} {...props} />
}

export { Separator, Skeleton, Checkbox, Kbd, Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

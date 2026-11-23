import * as React from 'react'
import { Tabs as TabsPrimitive } from 'radix-ui'
import { cn } from '@/lib/utils'

function Tabs({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return <TabsPrimitive.Root data-slot="tabs" className={cn('flex flex-col gap-3', className)} {...props} />
}

/** `variant="line"` is the page-level tab bar (detail pages); default is a segmented pill. */
function TabsList({
  className,
  variant = 'pill',
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List> & { variant?: 'pill' | 'line' }) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      data-variant={variant}
      className={cn(
        'group/tabs inline-flex w-fit items-center text-muted-foreground',
        variant === 'pill' && 'h-10 rounded-lg bg-secondary p-1',
        variant === 'line' && 'h-11 w-full justify-start gap-6 border-b',
        className,
      )}
      {...props}
    />
  )
}

function TabsTrigger({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        'inline-flex items-center justify-center gap-1.5 whitespace-nowrap text-[15px] font-medium transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&_svg]:size-4 [&_svg]:shrink-0',
        'group-data-[variant=pill]/tabs:h-full group-data-[variant=pill]/tabs:flex-1 group-data-[variant=pill]/tabs:rounded-md group-data-[variant=pill]/tabs:px-4 group-data-[variant=pill]/tabs:data-[state=active]:bg-card group-data-[variant=pill]/tabs:data-[state=active]:shadow-xs group-data-[variant=pill]/tabs:data-[state=active]:text-foreground',
        'group-data-[variant=line]/tabs:-mb-px group-data-[variant=line]/tabs:h-full group-data-[variant=line]/tabs:border-b-2 group-data-[variant=line]/tabs:border-transparent group-data-[variant=line]/tabs:hover:text-foreground group-data-[variant=line]/tabs:data-[state=active]:border-foreground group-data-[variant=line]/tabs:data-[state=active]:text-foreground',
        className,
      )}
      {...props}
    />
  )
}

function TabsContent({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Content>) {
  return <TabsPrimitive.Content data-slot="tabs-content" className={cn('flex-1 outline-none', className)} {...props} />
}

export { Tabs, TabsList, TabsTrigger, TabsContent }

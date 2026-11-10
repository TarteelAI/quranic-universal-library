import * as React from 'react'
import { Slot } from 'radix-ui'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium transition-all outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:ring-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        /** Ink — the main action in a view */
        default: 'bg-primary text-primary-foreground hover:bg-primary/85',
        /** QUL green with ink text. At most one per page, for the action you want noticed. */
        brand: 'bg-brand text-foreground hover:bg-brand/85',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-foreground/10',
        /** Hairline border on card white */
        outline: 'border bg-card shadow-xs hover:border-foreground/25 hover:bg-accent',
        ghost: 'hover:bg-foreground/[0.05]',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        link: 'h-auto px-0 text-foreground underline decoration-foreground/30 underline-offset-4 hover:decoration-foreground has-[>svg]:px-0',
      },
      size: {
        default: 'h-10 px-4 has-[>svg]:px-3.5',
        sm: 'h-8 gap-1.5 rounded-md px-3 text-[13px] has-[>svg]:px-2.5',
        lg: 'h-11 px-5 text-[15px] has-[>svg]:px-4.5',
        icon: 'size-10',
        'icon-sm': 'size-8 rounded-md',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

export interface ButtonProps extends React.ComponentProps<'button'>, VariantProps<typeof buttonVariants> {
  /** Render as the child element (e.g. an <a> or Inertia <Link>) */
  asChild?: boolean
}

function Button({ className, variant, size, asChild = false, ...props }: ButtonProps) {
  const Comp = asChild ? Slot.Root : 'button'
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size, className }))} {...props} />
}

export { Button, buttonVariants }

import { MonitorIcon, MoonIcon, SunIcon } from 'lucide-react'
import { RadioGroup as RadioGroupPrimitive } from 'radix-ui'

import { Button } from '@/components/ui/button'
import { chooseTheme, type ThemePreference, useThemePreference } from '@/lib/theme'
import { cn } from '@/lib/utils'

const OPTIONS = [
  { value: 'light', label: 'Light theme', Icon: SunIcon },
  { value: 'dark', label: 'Dark theme', Icon: MoonIcon },
  { value: 'system', label: 'System theme', Icon: MonitorIcon },
] as const

// Light, dark or system (follows the operating-system setting), remembered in lib/theme.ts.
// No option is checked on the server and while the page hydrates: only the browser knows the choice.
function ThemeSwitch({ className }: { className?: string }) {
  const preference = useThemePreference()

  return (
    <RadioGroupPrimitive.Root
      aria-label="Theme"
      orientation="horizontal"
      value={preference ?? ''}
      onValueChange={(value) => chooseTheme(value as ThemePreference)}
      className={cn('inline-flex h-8 items-center gap-0.5 rounded-full border bg-card p-0.5', className)}
    >
      {OPTIONS.map(({ value, label, Icon }) => (
        <RadioGroupPrimitive.Item
          key={value}
          value={value}
          aria-label={label}
          title={label}
          className="inline-flex size-7 items-center justify-center rounded-full text-muted-foreground transition-colors outline-none hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 data-[state=checked]:bg-foreground/[0.09] data-[state=checked]:text-foreground [&_svg]:size-3.5"
        >
          <Icon />
        </RadioGroupPrimitive.Item>
      ))}
    </RadioGroupPrimitive.Root>
  )
}

// One button that shows the current choice and moves to the next one (light, dark, system) on
// each press. Like the switch, it shows no choice on the server and while the page hydrates.
function ThemeCycle({ className }: { className?: string }) {
  const preference = useThemePreference()
  const index = OPTIONS.findIndex((option) => option.value === preference)
  const current = OPTIONS[index]
  const next = OPTIONS[(index + 1) % OPTIONS.length]
  const label = current ? `${current.label}. Switch to ${next.label.toLowerCase()}` : 'Theme'

  return (
    <Button
      variant="ghost"
      size="icon-sm"
      aria-label={label}
      title={label}
      onClick={() => chooseTheme(next.value)}
      className={className}
    >
      {current ? <current.Icon /> : <span className="size-4" />}
    </Button>
  )
}

export { ThemeCycle, ThemeSwitch }

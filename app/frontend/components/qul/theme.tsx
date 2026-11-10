import { MoonIcon, SunIcon } from 'lucide-react'

import { chooseTheme, type Theme, useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'

// The theme is unknown (null) on the server and while the page hydrates.
function toggleLabel(theme: Theme | null) {
  if (theme === 'dark') return 'Use the light theme'
  if (theme === 'light') return 'Use the dark theme'
  return 'Change the theme'
}

// Switches between the light and dark theme and remembers the choice (lib/theme.ts).
function ThemeToggle({ className }: { className?: string }) {
  const theme = useTheme()
  const label = toggleLabel(theme)

  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={() => chooseTheme(theme === 'dark' ? 'light' : 'dark')}
      className={cn(
        'inline-flex size-9 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-foreground/[0.05] hover:text-foreground [&_svg]:size-4',
        className,
      )}
    >
      {theme === 'dark' ? <SunIcon /> : <MoonIcon />}
    </button>
  )
}

export { ThemeToggle }

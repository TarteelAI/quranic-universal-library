import { categoryTile } from '@/components/qul/icons'
import { cn } from '@/lib/utils'
import type { SiteApp } from '@/types/serializers'

const SIZE = { sm: 'size-10 text-sm', md: 'size-12 text-base' } as const

export interface AppIconProps {
  app: Pick<SiteApp, 'name' | 'iconUrl' | 'uses'>
  size?: keyof typeof SIZE
  className?: string
}

// "Quran Reader for GNOME" → "QR", "QuranWBW" → "QW", "quran_library" → "QL".
function initials(name: string) {
  return name
    .replace(/\(.*\)/g, '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0])
    .join('')
    .toUpperCase()
}

/**
 * An app's icon as a rounded square; without one, its initials on the colour of the first QUL
 * resource it uses. From the v7 design (ds/src/app/pages/apps.tsx).
 */
function AppIcon({ app, size = 'md', className }: AppIconProps) {
  const box = cn('shrink-0 rounded-[22.5%] border border-foreground/10', SIZE[size], className)
  if (app.iconUrl)
    return <img src={app.iconUrl} alt="" loading="lazy" decoding="async" className={cn(box, 'bg-white object-cover')} />
  return (
    <span
      aria-hidden="true"
      className={cn(
        box,
        'inline-flex items-center justify-center font-medium tracking-tight',
        categoryTile(app.uses[0].category),
      )}
    >
      {initials(app.name)}
    </span>
  )
}

export { AppIcon }

import * as React from 'react'
import { cn } from '@/lib/utils'
import type { CatalogCategory } from '@/types/serializers'

type Category = CatalogCategory['key']

/*
 * QUL icon set: 24×24, 1.6 stroke, with a soft duotone fill (opacity .16)
 * so icons read as "illustrations" at 40px+ and stay crisp at 16px.
 */

type Glyph = React.ReactNode

const S = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.6,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
} as const
const D = { fill: 'currentColor', fillOpacity: 0.16, stroke: 'none' } as const

const GLYPHS = {
  /* ---- categories ---- */
  audio: (
    <>
      <rect x="3" y="3" width="18" height="18" rx="5" {...D} />
      <path d="M7 10v4M10 7.5v9M13 9v6M16 6.5v11M19 10.5v3" {...S} />
    </>
  ),
  layout: (
    <>
      <rect x="5" y="2.5" width="14" height="19" rx="2" {...D} />
      <rect x="5" y="2.5" width="14" height="19" rx="2" {...S} />
      <path d="M8 7h8M8 10h8M8 13h8M8 16h5" {...S} />
    </>
  ),
  script: (
    <>
      <circle cx="12" cy="13" r="8" {...D} />
      <path d="M5 11.5c0 4.4 3.1 7 7 7s7-2.6 7-7" {...S} />
      <circle cx="12" cy="8" r="1.4" fill="currentColor" stroke="none" />
    </>
  ),
  translation: (
    <>
      <rect x="2.5" y="4" width="12" height="11" rx="2.5" {...D} />
      <rect x="2.5" y="4" width="12" height="11" rx="2.5" {...S} />
      <path d="M9.5 9H21.5v10.5h-2.5l-2.5 2-1.5-2H9.5z" {...S} />
      <path d="M5.5 8h6M5.5 11h3.5M13 13.5h5.5M13 16.5h3.5" {...S} />
    </>
  ),
  tafsir: (
    <>
      <path d="M12 6.5C10 5 7 4.5 3 5v13.5c4-.5 7 0 9 1.5 2-1.5 5-2 9-1.5V5c-4-.5-7 0-9 1.5z" {...D} />
      <path d="M12 6.5C10 5 7 4.5 3 5v13.5c4-.5 7 0 9 1.5 2-1.5 5-2 9-1.5V5c-4-.5-7 0-9 1.5zM12 6.5V20" {...S} />
      <path d="M6 9h3M6 12h3M15 9h3M15 12h3" {...S} />
    </>
  ),
  linguistics: (
    <>
      <circle cx="12" cy="5" r="2.5" {...D} />
      <circle cx="12" cy="5" r="2.5" {...S} />
      <circle cx="5.5" cy="18.5" r="2.5" {...S} />
      <circle cx="12" cy="18.5" r="2.5" {...S} />
      <circle cx="18.5" cy="18.5" r="2.5" {...S} />
      <path d="M10.5 7 6.5 16M12 7.5V16M13.5 7l4 9" {...S} />
    </>
  ),
  topics: (
    <>
      <path d="M3.5 12.6V4.5a1 1 0 0 1 1-1h8.1l8.4 8.4a1.5 1.5 0 0 1 0 2.1l-7 7a1.5 1.5 0 0 1-2.1 0z" {...D} />
      <path d="M3.5 12.6V4.5a1 1 0 0 1 1-1h8.1l8.4 8.4a1.5 1.5 0 0 1 0 2.1l-7 7a1.5 1.5 0 0 1-2.1 0z" {...S} />
      <circle cx="8" cy="8" r="1.5" {...S} />
    </>
  ),
  metadata: (
    <>
      <rect x="3" y="3" width="8" height="8" rx="2" {...D} />
      <rect x="3" y="3" width="8" height="8" rx="2" {...S} />
      <rect x="13" y="3" width="8" height="8" rx="2" {...S} />
      <rect x="3" y="13" width="8" height="8" rx="2" {...S} />
      <rect x="13" y="13" width="8" height="8" rx="2" {...D} />
      <rect x="13" y="13" width="8" height="8" rx="2" {...S} />
    </>
  ),

  /* ---- goals ---- */
  reader: (
    <>
      <rect x="6" y="2" width="12" height="20" rx="3" {...D} />
      <rect x="6" y="2" width="12" height="20" rx="3" {...S} />
      <path d="M9 7h6M9 10h6M9 13h6M9 16h3.5" {...S} />
    </>
  ),
  'audio-goal': (
    <>
      <path d="M4 14v-2a8 8 0 0 1 16 0v2" {...S} />
      <rect x="3" y="13.5" width="5" height="7" rx="2" {...D} />
      <rect x="3" y="13.5" width="5" height="7" rx="2" {...S} />
      <rect x="16" y="13.5" width="5" height="7" rx="2" {...D} />
      <rect x="16" y="13.5" width="5" height="7" rx="2" {...S} />
    </>
  ),
  study: (
    <>
      <path d="M12 6.5C10 5 7 4.5 3 5v13.5c4-.5 7 0 9 1.5 2-1.5 5-2 9-1.5V5c-4-.5-7 0-9 1.5zM12 6.5V20" {...S} />
      <path d="M15 4.5v7l1.75-1.3 1.75 1.3V4.2" {...D} />
      <path d="M15 4.5v7l1.75-1.3 1.75 1.3V4.2" {...S} />
    </>
  ),
  learning: (
    <>
      <rect x="2.5" y="5" width="8" height="6" rx="1.5" {...D} />
      <rect x="2.5" y="5" width="8" height="6" rx="1.5" {...S} />
      <rect x="13.5" y="5" width="8" height="6" rx="1.5" {...S} />
      <path d="M4.5 15h4M15.5 15h4M5.5 18h2M16.5 18h2" {...S} />
    </>
  ),
  research: (
    <>
      <circle cx="10.5" cy="10.5" r="6.5" {...D} />
      <circle cx="10.5" cy="10.5" r="6.5" {...S} />
      <path d="m15.5 15.5 5 5" {...S} />
      <path d="M10.5 6.8l1 2.7 2.7 1-2.7 1-1 2.7-1-2.7-2.7-1 2.7-1z" fill="currentColor" stroke="none" />
    </>
  ),
  print: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2.5" {...D} />
      <rect x="3" y="4" width="18" height="16" rx="2.5" {...S} />
      <path d="m3.5 17 5-5 4 4 3-3 5 5" {...S} />
      <circle cx="16" cy="8.5" r="1.5" {...S} />
    </>
  ),

  /* ---- tool groups / misc ---- */
  proofread: (
    <>
      <rect x="3" y="3" width="14" height="18" rx="2" {...D} />
      <path d="M6.5 7.5h7M6.5 11h7M6.5 14.5h3.5" {...S} />
      <path d="M17 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h7" {...S} />
      <path d="m14.5 18 2.5 2.5 4.5-5" {...S} />
    </>
  ),
  request: (
    <>
      <circle cx="12" cy="12" r="9" {...D} />
      <circle cx="12" cy="12" r="9" {...S} />
      <path d="M12 8v8M8 12h8" {...S} />
    </>
  ),
  bundle: (
    <>
      <path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5z" {...D} />
      <path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5zM3.5 7.5 12 12l8.5-4.5M12 12v9" {...S} />
    </>
  ),
  agent: (
    <>
      <rect x="4" y="7" width="16" height="12" rx="3.5" {...D} />
      <rect x="4" y="7" width="16" height="12" rx="3.5" {...S} />
      <path d="M12 3.5V7M9 12.5v1.5M15 12.5v1.5M2 12v3M22 12v3" {...S} />
    </>
  ),
} satisfies Record<string, Glyph>

export type IconName = keyof typeof GLYPHS

export interface QulIconProps extends Omit<React.SVGProps<SVGSVGElement>, 'name'> {
  name: IconName
  size?: number
}

/** Low-level glyph. Inherits colour from `currentColor`. */
function QulIcon({ name, size = 24, className, ...props }: QulIconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      aria-hidden="true"
      className={cn('shrink-0', className)}
      {...props}
    >
      {GLYPHS[name]}
    </svg>
  )
}

const CAT_TEXT: Record<Category, string> = {
  audio: 'text-cat-audio',
  layout: 'text-cat-layout',
  script: 'text-cat-script',
  translation: 'text-cat-translation',
  tafsir: 'text-cat-tafsir',
  linguistics: 'text-cat-linguistics',
  topics: 'text-cat-topics',
  metadata: 'text-cat-metadata',
}
const CAT_TILE: Record<Category, string> = {
  audio: 'bg-cat-audio-subtle text-cat-audio',
  layout: 'bg-cat-layout-subtle text-cat-layout',
  script: 'bg-cat-script-subtle text-cat-script',
  translation: 'bg-cat-translation-subtle text-cat-translation',
  tafsir: 'bg-cat-tafsir-subtle text-cat-tafsir',
  linguistics: 'bg-cat-linguistics-subtle text-cat-linguistics',
  topics: 'bg-cat-topics-subtle text-cat-topics',
  metadata: 'bg-cat-metadata-subtle text-cat-metadata',
}

export interface ResourceIconProps {
  /** The resource category, which picks the glyph and its colour. */
  category: Category
  /** `tile` puts the glyph on a pale category square; `ring` on a neutral bordered square. */
  variant?: 'plain' | 'tile' | 'ring'
  size?: 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

const TILE_SIZE = { sm: 'size-7', md: 'size-10', lg: 'size-12', xl: 'size-16' }
const GLYPH_SIZE = { sm: 16, md: 22, lg: 26, xl: 34 }

/** Icon for a resource category, in the category colour. */
function ResourceIcon({ category, variant = 'tile', size = 'md', className }: ResourceIconProps) {
  const glyph = <QulIcon name={category} size={GLYPH_SIZE[size]} />
  if (variant === 'plain') return <span className={cn('inline-flex', CAT_TEXT[category], className)}>{glyph}</span>
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center justify-center rounded-[28%]',
        TILE_SIZE[size],
        variant === 'ring' ? 'border bg-card text-foreground' : CAT_TILE[category],
        className,
      )}
    >
      {glyph}
    </span>
  )
}

/** The GitHub mark, in the current text colour. */
function GitHubMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" className={cn('size-4 fill-current', className)} aria-hidden="true">
      <path d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z" />
    </svg>
  )
}

/** The pale category square of a tile, for other tiles in the category colour. */
function categoryTile(category: Category) {
  return CAT_TILE[category]
}

export { QulIcon, ResourceIcon, GitHubMark, categoryTile }

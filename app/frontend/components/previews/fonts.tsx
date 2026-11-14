import * as React from 'react'

import type { FontFiles } from '@/types/serializers'

// The light palette the old preview applies to the V4 Tajweed page fonts.
const V4_LIGHT_COLORS = [
  '#000000',
  '#A5A5A5',
  '#A5A5A5',
  '#B50000',
  '#FF7B00',
  '#CE9E00',
  '#09B000',
  '#3F48E6',
  '#2FADFF',
  '#F40000',
  '#2CA4AB',
  '#FF0080',
  '#D8E9D8',
  '#000000',
  '#000000',
  '#A5A5A5',
  '#CC9E00',
  '#00B000',
]

export const V4_PALETTE = '--qul-v4-light'

// Glyph fonts draw private-use code points, so their text must not show in a fallback font.
// Family names and URLs come from Fonts::UrlResolver, which keeps only path characters.
function fontFace(font: FontFiles): string {
  const src = font.sources.map((source) => `url('${source.url}') format('${source.format}')`).join(', ')
  return `@font-face{font-family:'${font.family}';src:${src};font-display:${font.perPage ? 'block' : 'swap'};}`
}

// One rule for every family: a later rule with the same name would replace it.
function v4Palette(fonts: FontFiles[], name: string): string {
  const families = fonts.map((font) => `'${font.family}'`).join(',')
  const colors = V4_LIGHT_COLORS.map((color, index) => `${index} ${color}`).join(',')
  return `@font-palette-values ${name}{font-family:${families};base-palette:0;override-colors:${colors};}`
}

// The @font-face rules of the fonts a preview shows, and nothing else. The element is
// re-rendered with the next page's rules when the preview pages, so rules never pile up, and
// the browser only downloads the files of the fonts the page uses. It renders the same on the
// server. React escapes quotes in <style> text children, hence the inner HTML. `palette` lists
// the V4 Tajweed fonts, which get the light colour palette, named `paletteName` (V4_PALETTE
// unless several previews share the page).
export function FontFaces({
  fonts,
  palette = [],
  paletteName = V4_PALETTE,
}: {
  fonts: FontFiles[]
  palette?: FontFiles[]
  paletteName?: string
}) {
  const css = [...fonts.map(fontFace), ...(palette.length > 0 ? [v4Palette(palette, paletteName)] : [])].join('\n')
  return <style dangerouslySetInnerHTML={{ __html: css }} />
}

export type FontStatus = 'loading' | 'loaded' | 'failed'

// Whether a font face from FontFaces has loaded, for the text it is asked to draw. Loading
// starts in the browser after the first render; on the server the status stays 'loading'.
export function useFontStatus(family: string | null, text: string): FontStatus {
  const [status, setStatus] = React.useState<{ key: string; value: FontStatus }>({ key: '', value: 'loading' })
  const key = `${family}\n${text}`

  React.useEffect(() => {
    if (!family) return
    let current = true
    document.fonts
      .load(`40px '${family}'`, text || undefined)
      .then((faces) => current && setStatus({ key, value: faces.length > 0 ? 'loaded' : 'failed' }))
      .catch(() => current && setStatus({ key, value: 'failed' }))
    return () => {
      current = false
    }
  }, [family, text, key])

  if (!family) return 'failed'
  return status.key === key ? status.value : 'loading'
}

export function FontFailed({ font }: { font: FontFiles }) {
  return (
    <p role="status" className="rounded-lg bg-warning-subtle p-3 text-sm text-warning">
      The font {font.family} could not be loaded from {font.sources.map((source) => source.url).join(' or ')}, so this
      text is not shown in it.
    </p>
  )
}

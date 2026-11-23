import * as React from 'react'

import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import type { PreviewsFont } from '@/types/serializers'

import { FontFaces, FontFailed, useFontStatus } from './fonts'
import { GlyphGrid } from './glyph-grid'
import { MushafPageView } from './mushaf-page'
import type { PreviewNavigation } from './navigation'

type View = PreviewsFont['view']

const VIEW_LABELS: Record<View, string> = { sample: 'Sample', ligatures: 'Ligatures', glyphs: 'Glyphs' }

// A font: its sample (or, for a font with one file per mushaf page, that page), the names it
// draws as ligatures, and every glyph in its file. The view is `?view=`.
export function FontPreview({ preview, navigation }: { preview: PreviewsFont; navigation: PreviewNavigation }) {
  const { font, page, ligatures } = preview
  const views: View[] = ['sample', ...(ligatures.length > 0 ? (['ligatures'] as const) : []), 'glyphs']
  const pageQuery = page ? { page: page.number } : {}

  return (
    <Tabs
      value={preview.view}
      onValueChange={(value) => {
        const view = value as View
        navigation.showView(view, view === 'sample' ? pageQuery : { ...pageQuery, view })
      }}
      className="flex flex-col gap-4"
      data-testid="font-preview"
      data-family={font.family}
    >
      <TabsList aria-label="Font views">
        {views.map((view) => (
          <TabsTrigger key={view} value={view}>
            {VIEW_LABELS[view]}
          </TabsTrigger>
        ))}
      </TabsList>
      <TabsContent value="sample">
        {page ? <MushafPageView page={page} navigation={navigation} /> : <Sample preview={preview} />}
      </TabsContent>
      {ligatures.length > 0 && (
        <TabsContent value="ligatures">
          <Ligatures preview={preview} />
        </TabsContent>
      )}
      <TabsContent value="glyphs">
        <FontFaces fonts={[font]} />
        <GlyphGrid font={font} />
      </TabsContent>
    </Tabs>
  )
}

function Sample({ preview }: { preview: PreviewsFont }) {
  const { font, sample } = preview
  const initial = sample?.text ?? ''
  const [text, setText] = React.useState(initial)
  const [size, setSize] = React.useState(40)
  const status = useFontStatus(font.family, initial)

  return (
    <div className="flex flex-col gap-4">
      <FontFaces fonts={[font]} />
      {status === 'failed' && <FontFailed font={font} />}
      <div
        dir="rtl"
        className="min-h-32 rounded-xl bg-card p-6 leading-[1.7] break-words whitespace-pre-line shadow-xs"
        style={{ fontFamily: `'${font.family}'`, fontSize: size }}
        data-testid="font-sample"
        data-font-status={status}
      >
        {text}
      </div>
      {sample?.source && <p className="text-xs text-muted-foreground">Sample: {sample.source}</p>}
      <label className="flex flex-col gap-1.5 text-sm font-medium">
        Your text
        <textarea
          dir="rtl"
          rows={3}
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="Type or paste text to see it in this font"
          className="rounded-lg border bg-card p-3 text-base font-normal shadow-xs"
        />
      </label>
      <label className="flex items-center gap-3 text-sm text-muted-foreground">
        Size
        <input type="range" min={12} max={160} value={size} onChange={(event) => setSize(Number(event.target.value))} />
        <span className="tabular-nums">{size}px</span>
      </label>
    </div>
  )
}

function Ligatures({ preview }: { preview: PreviewsFont }) {
  const { font, ligatures } = preview
  const [query, setQuery] = React.useState('')
  const shown = ligatures.filter((ligature) => ligature.name.toLowerCase().includes(query.trim().toLowerCase()))

  return (
    <div className="flex flex-col gap-4">
      <FontFaces fonts={[font]} />
      <p className="max-w-prose text-sm text-muted-foreground">
        This font draws each name below as a single glyph. Put the ligature text in your markup and render it with this
        font; the name itself is only a label.
      </p>
      <div className="flex flex-wrap items-center gap-3 text-sm">
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Filter by name"
          aria-label="Filter ligatures"
          className="h-8 rounded-md border bg-card px-2 shadow-xs"
        />
        <span className="text-muted-foreground" data-testid="ligature-count">
          {shown.length === ligatures.length
            ? `${ligatures.length} ligatures`
            : `${shown.length} of ${ligatures.length} ligatures`}
        </span>
      </div>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-sm">
          <thead className="border-b bg-muted/50 text-start">
            <tr>
              <th className="px-3 py-2 text-start font-medium">Name</th>
              <th className="px-3 py-2 text-start font-medium">Ligature text</th>
              <th className="px-3 py-2 text-start font-medium">Drawn</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((ligature) => (
              <tr key={ligature.name} className="border-b last:border-0" data-ligature={ligature.name}>
                <td className="px-3 py-2">{ligature.name}</td>
                <td className="px-3 py-2 font-mono text-xs">{ligature.text}</td>
                <td
                  className="max-w-80 overflow-hidden px-3 py-2 text-[40px] leading-normal whitespace-nowrap"
                  style={{ fontFamily: `'${font.family}'` }}
                >
                  {ligature.text}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

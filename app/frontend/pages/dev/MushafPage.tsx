import { Link } from '@inertiajs/react'
import type { CSSProperties } from 'react'

import { devMushafPage } from '@/routes'
import type { DevMushafPagesShow, FontFiles, MushafLayoutsLine } from '@/types/serializers'

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

// Glyph fonts draw private-use code points, so text must not show in a fallback font.
function fontFace(font: FontFiles): string {
  const src = font.sources.map((source) => `url('${source.url}') format('${source.format}')`).join(', ')
  return `@font-face{font-family:'${font.family}';src:${src};font-display:${font.perPage ? 'block' : 'swap'};}`
}

function v4Palette(font: FontFiles): string {
  const colors = V4_LIGHT_COLORS.map((color, index) => `${index} ${color}`).join(',')
  return `@font-palette-values --qul-v4-light{font-family:'${font.family}';base-palette:0;override-colors:${colors};}`
}

type Fonts = Pick<DevMushafPagesShow, 'surahNameFont' | 'surahHeaderFont' | 'bismillahFont'>

function SurahName({ number, fonts }: { number: number; fonts: Fonts }) {
  return (
    <div className="mx-auto mt-2.5 flex items-center justify-center">
      <div
        className="relative flex items-center justify-center text-[70px]"
        style={{ fontFamily: fonts.surahHeaderFont.family }}
      >
        header
        <div className="absolute text-[50px] leading-none" style={{ fontFamily: fonts.surahNameFont.family }}>
          <span className="me-2">{`surah${String(number).padStart(3, '0')}`}</span>
          <span>surah-icon</span>
        </div>
      </div>
    </div>
  )
}

function Line({ line, fonts }: { line: MushafLayoutsLine; fonts: Fonts }) {
  return (
    <div
      className={`whitespace-nowrap ${line.centered ? 'text-center' : 'text-justify [text-align-last:justify]'}`}
      data-line={line.number}
      data-centered={line.centered}
    >
      {line.surahNumber !== null && <SurahName number={line.surahNumber} fonts={fonts} />}
      {line.bismillah && (
        <div className="text-5xl" style={{ fontFamily: fonts.bismillahFont.family }} data-bismillah>
          ﷽
        </div>
      )}
      {line.words.map((word, index) => (
        <span key={word.id}>
          {index > 0 && ' '}
          <span className={word.charTypeName === 'end' ? 'text-[blue]' : undefined} data-word={word.id}>
            {word.text}
          </span>
        </span>
      ))}
    </div>
  )
}

export default function MushafPage({
  resourceId,
  name,
  fontCode,
  page,
  pagesCount,
  lines,
  textFont,
  surahNameFont,
  surahHeaderFont,
  bismillahFont,
}: DevMushafPagesShow) {
  const fonts = { surahNameFont, surahHeaderFont, bismillahFont }
  const decorations = [
    lines.some((line) => line.surahNumber !== null) && [surahHeaderFont, surahNameFont],
    lines.some((line) => line.bismillah) && [bismillahFont],
  ]
    .filter((group) => group !== false)
    .flat()
  const v4 = textFont && fontCode === 'v4-tajweed'
  const css = [textFont && fontFace(textFont), v4 && v4Palette(textFont), ...decorations.map(fontFace)]
    .filter(Boolean)
    .join('\n')
  const pageStyle: CSSProperties = {
    fontFamily: textFont ? `'${textFont.family}'` : undefined,
    fontPalette: v4 ? '--qul-v4-light' : undefined,
  }

  return (
    <main className="mx-auto max-w-4xl space-y-6 p-6 text-black">
      <style dangerouslySetInnerHTML={{ __html: css }} />
      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">
          {name}, page {page} of {pagesCount}
        </h1>
        <nav className="flex gap-3">
          {page > 1 && (
            <Link className="underline" href={devMushafPage(resourceId, { query: { page: page - 1 } }).url}>
              Previous
            </Link>
          )}
          {page < pagesCount && (
            <Link className="underline" href={devMushafPage(resourceId, { query: { page: page + 1 } }).url}>
              Next
            </Link>
          )}
        </nav>
      </header>

      {!textFont && <p role="status">This layout has no font ({fontCode}). It needs page images instead.</p>}
      {lines.length === 0 && <p role="status">This page has no word rows.</p>}

      <div className="flex justify-center rounded-xl bg-white p-6 shadow">
        <div dir="rtl" className="w-max text-[30px] leading-[1.85]" style={pageStyle} data-testid="mushaf-page">
          {lines.map((line) => (
            <Line key={line.number} line={line} fonts={fonts} />
          ))}
        </div>
      </div>
    </main>
  )
}

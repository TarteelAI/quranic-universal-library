import type { FontFiles, MushafLayoutsLine, PreviewsMushafPage } from '@/types/serializers'

import { FontFaces, FontFailed, useFontStatus, V4_PALETTE } from './fonts'
import { JumpTo, PreviewToolbar, selectClass, StepButtons, type PreviewNavigation } from './navigation'

type Decorations = Pick<PreviewsMushafPage, 'surahNameFont' | 'surahHeaderFont' | 'bismillahFont'>

function SurahName({ number, fonts }: { number: number; fonts: Decorations }) {
  return (
    <div className="mx-auto mt-2.5 flex items-center justify-center">
      <div
        className="relative flex items-center justify-center text-[2.33em]"
        style={{ fontFamily: fonts.surahHeaderFont.family }}
      >
        header
        <div className="absolute text-[0.72em] leading-none" style={{ fontFamily: fonts.surahNameFont.family }}>
          <span className="me-2">{`surah${String(number).padStart(3, '0')}`}</span>
          <span>surah-icon</span>
        </div>
      </div>
    </div>
  )
}

// Words are inline spans separated by spaces, one verse after another, as the old preview
// lays them out; a line never wraps (whitespace-nowrap) and justified lines fill the page width.
function Line({ line, fonts }: { line: MushafLayoutsLine; fonts: Decorations }) {
  return (
    <div
      className={`whitespace-nowrap ${line.centered ? 'text-center' : 'text-justify [text-align-last:justify]'}`}
      data-line={line.number}
      data-centered={line.centered}
    >
      {line.surahNumber !== null && <SurahName number={line.surahNumber} fonts={fonts} />}
      {line.bismillah && (
        <div className="text-[1.6em]" style={{ fontFamily: fonts.bismillahFont.family }} data-bismillah>
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

// The fonts a page needs: its text font, plus the surah-name and bismillah fonts only when the
// page has such lines.
function pageFonts(page: PreviewsMushafPage): FontFiles[] {
  const surahLine = page.lines.some((line) => line.surahNumber !== null)
  const bismillahLine = page.lines.some((line) => line.bismillah)
  return [
    ...(page.textFont ? [page.textFont] : []),
    ...(surahLine ? [page.surahHeaderFont, page.surahNameFont] : []),
    ...(bismillahLine ? [page.bismillahFont] : []),
  ]
}

// One mushaf page with its navigation: previous and next page, jump to a page, jump to the
// page a surah starts on.
export function MushafPageView({ page, navigation }: { page: PreviewsMushafPage; navigation: PreviewNavigation }) {
  const { navigate, loading } = navigation
  const textFont = page.textFont
  const v4 = textFont !== null && page.fontCode === 'v4-tajweed'
  const status = useFontStatus(
    textFont?.family ?? null,
    page.lines.find((line) => line.words.length > 0)?.words[0]?.text ?? '',
  )
  const surah = [...page.surahs].reverse().find((entry) => entry.page !== null && entry.page <= page.number)

  return (
    <div className="flex flex-col gap-4" data-testid="mushaf-preview" data-page={page.number}>
      <FontFaces fonts={pageFonts(page)} palette={v4 && textFont ? [textFont] : []} />
      <PreviewToolbar loading={loading}>
        <StepButtons
          label="page"
          previous={page.number > 1 ? () => navigate({ page: page.number - 1 }) : null}
          next={page.number < page.pagesCount ? () => navigate({ page: page.number + 1 }) : null}
        />
        <JumpTo
          label="Page"
          value={page.number}
          min={1}
          max={page.pagesCount}
          onJump={(number) => navigate({ page: number })}
        />
        <label className="flex items-center gap-1.5 text-muted-foreground">
          Surah
          <select
            className={selectClass}
            value={surah?.number ?? ''}
            onChange={(event) => {
              const target = page.surahs.find((entry) => entry.number === Number(event.target.value))
              if (target?.page) navigate({ page: target.page })
            }}
          >
            {page.surahs.map((entry) => (
              <option key={entry.number} value={entry.number} disabled={entry.page === null}>
                {entry.number}. {entry.name}
              </option>
            ))}
          </select>
        </label>
      </PreviewToolbar>

      <p className="text-sm text-muted-foreground">
        Page {page.number} of {page.pagesCount}
      </p>
      {textFont && status === 'failed' && <FontFailed font={textFont} />}
      {page.lines.length === 0 && <p role="status">This page has no word rows.</p>}

      <div className="overflow-x-auto rounded-xl bg-white p-4 text-black shadow-xs sm:p-6">
        <div
          dir="rtl"
          className="mx-auto w-max text-[18px] leading-[1.85] sm:text-[30px]"
          style={{
            fontFamily: textFont ? `'${textFont.family}'` : undefined,
            fontPalette: v4 ? V4_PALETTE : undefined,
          }}
          data-testid="mushaf-page"
          data-font-status={status}
          aria-busy={loading}
        >
          {page.lines.map((line) => (
            <Line key={line.number} line={line} fonts={page} />
          ))}
        </div>
      </div>
    </div>
  )
}

import type { PreviewsText, PreviewsTextEntry, PreviewsLocale } from '@/types/serializers'

import { AyahRangeToolbar, type PreviewNavigation } from './navigation'

// Text and footnotes are HTML the server sanitized (Previews.sanitize).
export function Html({ html, locale, className }: { html: string; locale: PreviewsLocale; className?: string }) {
  return (
    <div lang={locale.code} dir={locale.direction} className={className} dangerouslySetInnerHTML={{ __html: html }} />
  )
}

function Entry({ entry, preview }: { entry: PreviewsTextEntry; preview: PreviewsText }) {
  const { locale } = preview
  return (
    <li className="flex flex-col gap-3 rounded-xl border bg-card p-4" data-entry={entry.key}>
      <span className="font-mono text-xs text-muted-foreground">{entry.key}</span>
      {preview.granularity === 'word' ? (
        entry.words.length > 0 ? (
          <div dir="rtl" className="flex flex-wrap gap-2">
            {entry.words.map((word) => (
              <span key={word.id} className="flex flex-col items-center gap-1 rounded-md border px-3 py-2">
                <span lang="ar" className="font-arabic text-2xl">
                  {word.arabic}
                </span>
                <span lang={locale.code} dir={locale.direction} className="text-sm text-muted-foreground">
                  {word.text}
                </span>
              </span>
            ))}
          </div>
        ) : (
          <Missing />
        )
      ) : (
        <>
          <p dir="rtl" lang="ar" className="font-arabic text-2xl leading-loose">
            {entry.ayahs.map((ayah) => ayah.text).join(' ')}
          </p>
          {entry.text !== null ? (
            <Html html={entry.text} locale={locale} className="preview-html leading-relaxed" />
          ) : (
            <Missing />
          )}
          {entry.truncated && (
            <p className="text-sm text-muted-foreground">
              This entry is long, so the preview shows its start. Download the resource to read all of it.
            </p>
          )}
          {entry.footnotes.length > 0 && (
            <ol className="flex list-decimal flex-col gap-1 ps-6 text-sm text-muted-foreground" aria-label="Footnotes">
              {entry.footnotes.map((footnote) => (
                <li key={footnote.id}>
                  <Html html={footnote.text} locale={locale} />
                </li>
              ))}
            </ol>
          )}
        </>
      )}
    </li>
  )
}

function Missing() {
  return <p className="text-sm text-muted-foreground italic">No text for this ayah in this resource.</p>
}

// A translation, tafsir or transliteration: its text for a range of ayahs of one surah, in the
// text's own language and direction.
export function TextPreview({ preview, navigation }: { preview: PreviewsText; navigation: PreviewNavigation }) {
  const { surah, from, to } = preview
  return (
    <div
      className="flex flex-col gap-4"
      data-testid="text-preview"
      data-granularity={preview.granularity}
      data-surah={surah.number}
      data-from={from}
      data-to={to}
    >
      <AyahRangeToolbar surah={surah} surahs={preview.surahs} from={from} to={to} navigation={navigation} />
      <p className="text-sm text-muted-foreground">
        Surah {surah.name}, {from === to ? `ayah ${from}` : `ayahs ${from}–${to}`} of {surah.versesCount}
      </p>
      <ol className="flex flex-col gap-3" aria-busy={navigation.loading}>
        {preview.entries.map((entry) => (
          <Entry key={entry.key} entry={entry} preview={preview} />
        ))}
      </ol>
    </div>
  )
}

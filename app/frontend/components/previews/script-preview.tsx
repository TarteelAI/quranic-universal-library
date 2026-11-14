import { plainText } from '@/lib/format'
import type { PreviewsScript, PreviewsScriptAyah, PreviewsScriptToken } from '@/types/serializers'

import { FontFaces, FontFailed, useFontStatus, V4_PALETTE } from './fonts'
import { AyahRangeToolbar, type PreviewNavigation } from './navigation'

type Rendering = PreviewsScript['rendering']

function Text({ text, font, rendering }: { text: string | null; font: string | null; rendering: Rendering }) {
  const style = font ? { fontFamily: `'${font}'` } : undefined
  // Tajweed text holds <rule class="..."> tags, sanitized on the server to those alone.
  if (rendering === 'html') return <span style={style} dangerouslySetInnerHTML={{ __html: text ?? '' }} />
  return <span style={style}>{text}</span>
}

function Word({ token, rendering }: { token: PreviewsScriptToken; rendering: Rendering }) {
  if (rendering === 'image') {
    return token.imageUrl ? <img src={token.imageUrl} alt="" className="h-10 w-auto" loading="lazy" /> : null
  }
  return <Text text={token.text} font={token.font} rendering={rendering} />
}

// An ayah's text, or its words in a row.
export function AyahText({ ayah, rendering }: { ayah: PreviewsScriptAyah; rendering: Rendering }) {
  if (ayah.text !== null) return <Text text={ayah.text} font={ayah.font} rendering={rendering} />
  return ayah.words.map((token, index) => (
    <span key={token.id}>
      {index > 0 && ' '}
      <Word token={token} rendering={rendering} />
    </span>
  ))
}

function Ayah({ ayah, preview }: { ayah: PreviewsScriptAyah; preview: PreviewsScript }) {
  const { granularity, rendering } = preview
  return (
    <li className="flex flex-col gap-2" data-ayah={ayah.key}>
      <span dir="ltr" className="self-end font-sans text-xs text-neutral-500">
        {ayah.key}
      </span>
      {granularity === 'word' ? (
        <div className="flex flex-wrap gap-2">
          {ayah.words.map((token) => (
            <span key={token.id} className="rounded-md border border-neutral-200 px-3 py-1" data-word={token.id}>
              <Word token={token} rendering={rendering} />
            </span>
          ))}
        </div>
      ) : (
        <p>
          <AyahText ayah={ayah} rendering={rendering} />
        </p>
      )}
    </li>
  )
}

// A Quran script: a range of ayahs of one surah in the script's own text and font, with the
// surah picker and the previous and next range.
export function ScriptPreview({ preview, navigation }: { preview: PreviewsScript; navigation: PreviewNavigation }) {
  const { surah, from, to, fonts, ayahs } = preview
  const { loading } = navigation
  const firstText = ayahs[0]?.text ?? ayahs[0]?.words[0]?.text ?? ''
  const status = useFontStatus(fonts[0]?.family ?? null, plainText(firstText))
  const v4 = preview.fontCode === 'v4-tajweed'

  return (
    <div
      className="flex flex-col gap-4"
      data-testid="script-preview"
      data-granularity={preview.granularity}
      data-rendering={preview.rendering}
      data-surah={surah.number}
      data-from={from}
      data-to={to}
    >
      <FontFaces fonts={fonts} palette={v4 ? fonts : []} />
      <AyahRangeToolbar surah={surah} surahs={preview.surahs} from={from} to={to} navigation={navigation} />

      <p className="text-sm text-muted-foreground">
        Surah {surah.name}, {from === to ? `ayah ${from}` : `ayahs ${from}–${to}`} of {surah.versesCount}
      </p>
      {fonts[0] && status === 'failed' && <FontFailed font={fonts[0]} />}

      <ol
        dir="rtl"
        className={`flex flex-col gap-5 rounded-xl bg-white p-4 text-[28px] leading-[2] text-black shadow-xs sm:p-6 ${preview.rendering === 'html' ? 'tajweed' : ''}`}
        style={{ fontPalette: v4 ? V4_PALETTE : undefined }}
        data-testid="script-text"
        data-font-status={fonts.length > 0 ? status : 'none'}
        aria-busy={loading}
      >
        {ayahs.map((ayah) => (
          <Ayah key={ayah.key} ayah={ayah} preview={preview} />
        ))}
      </ol>
    </div>
  )
}

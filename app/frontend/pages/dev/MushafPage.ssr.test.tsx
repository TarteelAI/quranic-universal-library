// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import type { DevMushafPagesShow, FontFiles } from '@/types/serializers'

import MushafPage from './MushafPage'

function font(family: string, perPage = false): FontFiles {
  return { family, perPage, sources: [{ url: `https://cdn.example.test/${family}.woff2`, format: 'woff2' }] }
}

const props: DevMushafPagesShow = {
  resourceId: 19,
  name: 'KFGQPC V4 layout',
  fontCode: 'v4-tajweed',
  page: 2,
  pagesCount: 604,
  textFont: font('v4-tajweed-p2', true),
  surahNameFont: font('surah-name-v4'),
  surahHeaderFont: font('quran-common'),
  bismillahFont: font('bismillah'),
  lines: [
    { number: 1, centered: true, surahNumber: 2, bismillah: true, words: [] },
    {
      number: 2,
      centered: true,
      surahNumber: null,
      bismillah: false,
      words: [
        { id: 1, text: 'ﱁ', charTypeName: 'word', verseId: 8 },
        { id: 2, text: 'ﱂ', charTypeName: 'end', verseId: 8 },
      ],
    },
  ],
}

describe('dev/MushafPage on the server', () => {
  it('renders the lines and the page font without browser globals', async () => {
    const { body } = await renderPageOnServer(MushafPage, { props })

    expect(body).toContain(
      "@font-face{font-family:'v4-tajweed-p2';src:url('https://cdn.example.test/v4-tajweed-p2.woff2') format('woff2');font-display:block;}",
    )
    expect(body).toContain('@font-palette-values --qul-v4-light')
    expect(body).toContain("font-family:'surah-name-v4'")
    expect(body).toContain('surah002')
    expect(body).toContain('data-bismillah="true"')
    expect(body).toContain('ﱁ')
  })
})

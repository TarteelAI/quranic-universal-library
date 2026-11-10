import type { FontFiles, PreviewsFont, PreviewsMushafLayout, PreviewsScript } from '@/types/serializers'

const CDN = 'https://static-cdn.tarteel.ai/qul/fonts'

function font(family: string, path: string, perPage = false): FontFiles {
  return {
    family,
    perPage,
    sources: [
      { url: `${CDN}/${path}.woff2`, format: 'woff2' },
      { url: `${CDN}/${path}.ttf`, format: 'truetype' },
    ],
  }
}

const decorations = {
  surahNameFont: font('surah-name-v4', 'surah-names/v4/surah-name-v4'),
  surahHeaderFont: font('quran-common', 'common/quran-common'),
  bismillahFont: font('bismillah', 'bismillah/bismillah'),
}

// Page 2 of the V2 layout, cut down: the surah-name line, the bismillah line and one line of words.
export const layoutPreview: PreviewsMushafLayout = {
  kind: 'layout',
  page: {
    number: 2,
    pagesCount: 604,
    fontCode: 'v2',
    textFont: font('v2-p2', 'quran_fonts/v2/woff2/p2', true),
    ...decorations,
    lines: [
      { number: 1, centered: true, surahNumber: 2, bismillah: false, words: [] },
      { number: 2, centered: true, surahNumber: null, bismillah: true, words: [] },
      {
        number: 3,
        centered: false,
        surahNumber: null,
        bismillah: false,
        words: [
          { id: 101, text: 'ﱁ', charTypeName: 'word', verseId: 8 },
          { id: 102, text: 'ﱂ', charTypeName: 'end', verseId: 8 },
        ],
      },
    ],
    surahs: [
      { number: 1, name: 'Al-Fatihah', page: 1 },
      { number: 2, name: 'Al-Baqarah', page: 2 },
      { number: 3, name: 'Ali Imran', page: 50 },
    ],
  },
}

export const fontPreview: PreviewsFont = {
  kind: 'font',
  view: 'sample',
  font: font('surah-name-v4-icon', 'surah-names/v4/surah-name-v4'),
  sample: { text: 'surah001', source: null },
  ligatures: [
    { name: 'surah icon', text: 'surah-icon' },
    { name: 'surah-1', text: 'surah001' },
    { name: 'surah-2', text: 'surah002' },
  ],
  page: null,
}

export const scriptPreview: PreviewsScript = {
  kind: 'script',
  granularity: 'word',
  rendering: 'text',
  fontCode: 'v2',
  fonts: [font('v2-p604', 'quran_fonts/v2/woff2/p604', true)],
  surah: { number: 112, name: 'Al-Ikhlas', versesCount: 4 },
  from: 1,
  to: 2,
  ayahs: [
    {
      key: '112:1',
      number: 1,
      text: null,
      font: null,
      words: [
        { id: 1, text: 'ﱁ', font: 'v2-p604', imageUrl: null },
        { id: 2, text: 'ﱂ', font: 'v2-p604', imageUrl: null },
      ],
    },
    { key: '112:2', number: 2, text: null, font: null, words: [{ id: 3, text: 'ﱆ', font: 'v2-p604', imageUrl: null }] },
  ],
  surahs: [
    { number: 1, name: 'Al-Fatihah', versesCount: 7 },
    { number: 112, name: 'Al-Ikhlas', versesCount: 4 },
  ],
}

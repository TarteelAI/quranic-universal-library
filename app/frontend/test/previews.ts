import type {
  FontFiles,
  PreviewsCardFont,
  PreviewsCardLayout,
  PreviewsCardRecitation,
  PreviewsCardScript,
  PreviewsCardText,
  PreviewsFont,
  PreviewsMushafLayout,
  PreviewsRecitation,
  PreviewsRecords,
  PreviewsScript,
  PreviewsText,
} from '@/types/serializers'

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

const surahs = [
  { number: 1, name: 'Al-Fatihah', versesCount: 7 },
  { number: 2, name: 'Al-Baqarah', versesCount: 286 },
  { number: 114, name: 'An-Nas', versesCount: 6 },
]

// Al-Fatihah by Mahmoud Khalil Al-Husary (mujawwad), with the segment times of the snapshot.
const fatihah: [string, number, number][] = [
  ['بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', 0, 4470],
  ['ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ', 4670, 12540],
  ['ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', 15670, 21595],
  ['مَـٰلِكِ يَوْمِ ٱلدِّينِ', 24025, 29895],
  ['إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 33045, 42510],
  ['ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ', 45800, 53150],
  ['صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ', 55940, 75389],
]

export const recitationPreview: PreviewsRecitation = {
  kind: 'recitation',
  granularity: 'surah',
  highlights: true,
  tracks: ['https://audio-cdn.tarteel.ai/quran/surah/husary/mujawwad/mp3/001.mp3'],
  surah: surahs[0],
  ayahs: fatihah.map(([text, from, to], index) => ({
    key: `1:${index + 1}`,
    number: index + 1,
    text,
    track: 0,
    from,
    to,
  })),
  surahs,
}

export const unsegmentedRecitationPreview: PreviewsRecitation = {
  ...recitationPreview,
  highlights: false,
  ayahs: recitationPreview.ayahs.map((ayah) => ({ ...ayah, from: null, to: null })),
}

export const ayahRecitationPreview: PreviewsRecitation = {
  ...recitationPreview,
  granularity: 'ayah',
  tracks: fatihah.map((_, index) => `https://audio-cdn.tarteel.ai/quran/alafasy/00100${index + 1}.mp3`),
  ayahs: recitationPreview.ayahs.map((ayah, index) => ({ ...ayah, track: index, from: 0, to: null })),
}

export const translationPreview: PreviewsText = {
  kind: 'text',
  granularity: 'ayah',
  locale: { code: 'ur', direction: 'rtl' },
  surah: surahs[1],
  from: 1,
  to: 2,
  entries: [
    {
      key: '2:1',
      ayahs: [{ key: '2:1', text: 'الٓمٓ' }],
      text: 'الم<sup>1</sup>',
      truncated: false,
      footnotes: [{ id: 7, text: 'حروف <b>مقطعات</b>' }],
      words: [],
    },
    {
      key: '2:2',
      ayahs: [{ key: '2:2', text: 'ذَٰلِكَ ٱلْكِتَـٰبُ' }],
      text: null,
      truncated: false,
      footnotes: [],
      words: [],
    },
  ],
  surahs,
}

export const wordTranslationPreview: PreviewsText = {
  ...translationPreview,
  granularity: 'word',
  locale: { code: 'en', direction: 'ltr' },
  surah: surahs[0],
  from: 1,
  to: 1,
  entries: [
    {
      key: '1:1',
      ayahs: [{ key: '1:1', text: fatihah[0][0] }],
      text: null,
      truncated: false,
      footnotes: [],
      words: [
        { id: 1, arabic: 'بِسْمِ', text: 'In (the) name' },
        { id: 2, arabic: 'ٱللَّهِ', text: '(of) Allah' },
      ],
    },
  ],
}

export const recordsPreview: PreviewsRecords = {
  kind: 'records',
  limit: 10,
  surah: surahs[0],
  surahs,
  locale: { code: 'en', direction: 'ltr' },
  records: [
    {
      key: '1',
      label: '1:1–1:7',
      arabic: null,
      text: 'Supplication to Allah for guidance taught by Allah Himself',
      html: null,
      truncated: false,
      tags: ['Supplic', 'Allah'],
    },
  ],
}

// Card previews (Previews::Card), cut from the detail previews above as the server cuts them.
const { number, fontCode, textFont, lines } = layoutPreview.page
export const cardLayoutPreview: PreviewsCardLayout = {
  kind: 'layout',
  page: { number, fontCode, textFont, ...decorations, lines },
}

export const cardRecitationPreview: PreviewsCardRecitation = {
  kind: 'recitation',
  granularity: recitationPreview.granularity,
  highlights: recitationPreview.highlights,
  tracks: recitationPreview.tracks,
  surah: recitationPreview.surah,
}

export const cardAyahRecitationPreview: PreviewsCardRecitation = {
  ...cardRecitationPreview,
  granularity: 'ayah',
  tracks: ayahRecitationPreview.tracks,
}

export const cardScriptPreview: PreviewsCardScript = {
  kind: 'script',
  granularity: scriptPreview.granularity,
  rendering: scriptPreview.rendering,
  fontCode: scriptPreview.fontCode,
  fonts: scriptPreview.fonts,
  ayah: scriptPreview.ayahs[0],
}

export const cardTextPreview: PreviewsCardText = {
  kind: 'text',
  granularity: 'ayah',
  locale: translationPreview.locale,
  entry: translationPreview.entries[0],
}

export const cardFontPreview: PreviewsCardFont = {
  kind: 'font',
  fontCode: null,
  text: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
  font: font('qpc-hafs', 'hafs/qpc-hafs'),
}

// A V4 Tajweed page font: a line of page 1 in the file of page 1.
export const cardV4FontPreview: PreviewsCardFont = {
  kind: 'font',
  fontCode: 'v4-tajweed',
  text: 'ﱁ ﱂ ﱃ ﱄ',
  font: font('v4-p1', 'v4/p1', true),
}

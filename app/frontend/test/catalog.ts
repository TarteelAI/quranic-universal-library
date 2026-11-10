import type { CatalogResourceCard, CatalogResourcesIndex, CatalogType, CatalogTypesShow } from '@/types/serializers'

const translation = {
  key: 'translation',
  label: 'Translation',
  title: 'Translations',
  summary: 'Ayah by ayah and word by word translations in many languages.',
  description: 'Translations of the Quran in many languages.',
  category: { key: 'translation', label: 'Translation' },
} satisfies CatalogType

const tafsir = {
  key: 'tafsir',
  label: 'Tafsir',
  title: 'Tafsirs',
  summary: 'Short and detailed commentaries.',
  description: 'Commentaries on the Quran in many languages.',
  category: { key: 'tafsir', label: 'Tafsir and commentary' },
} satisfies CatalogType

// Props of catalog/TypePage, shaped like Catalog::TypesShowResource.
export const typePageProps: CatalogTypesShow = {
  type: translation,
  types: [translation, tafsir],
  resources: [
    {
      id: 1,
      name: 'Sahih International',
      type: 'translation',
      toParam: 'sahih-international',
      filesCount: 3,
      language: 'English',
      granularity: 'Ayah by Ayah',
      status: 'stable',
      scriptFamily: null,
      recommendation: null,
      supersededBy: null,
    },
    {
      id: 2,
      name: 'Word by word in Urdu',
      type: 'translation',
      toParam: '2',
      filesCount: 1,
      language: null,
      granularity: 'Word by word',
      status: 'stable',
      scriptFamily: null,
      recommendation: null,
      supersededBy: null,
    },
  ],
  statuses: [
    { key: 'stable', label: 'Stable' },
    { key: 'beta', label: 'Beta' },
    { key: 'legacy', label: 'Legacy' },
    { key: 'superseded', label: 'Superseded' },
  ],
  pick: null,
  comparison: null,
}

const layoutType = {
  key: 'mushaf-layout',
  label: 'Mushaf layout',
  title: 'Mushaf layouts',
  summary: 'Page, line and word positions of printed mushaf editions.',
  description: 'Page, line and word positions of printed mushaf editions.',
  category: { key: 'layout', label: 'Mushaf layouts' },
} satisfies CatalogType

function layout(id: number, name: string, fields: Partial<CatalogResourceCard> = {}): CatalogResourceCard {
  return {
    id,
    name,
    type: 'mushaf-layout',
    toParam: name.toLowerCase().replaceAll(' ', '-'),
    filesCount: 2,
    language: null,
    granularity: null,
    status: 'stable',
    scriptFamily: 'Madani',
    recommendation: null,
    supersededBy: null,
    ...fields,
  }
}

const qpcV2 = { id: 3, name: 'QPC V2 Font', type: 'font', toParam: 'qpc-v2-font' }

// Props of a type page with status data: a reviewed and a drafted recommendation, a current
// layout, a legacy one and a superseded one, and the comparison table.
export const layoutPageProps: CatalogTypesShow = {
  ...typePageProps,
  type: layoutType,
  types: [layoutType, translation],
  resources: [
    layout(10, 'KFGQPC V2 layout', { recommendation: 'reviewed' }),
    layout(11, 'Indopak 15 lines', { recommendation: 'drafted', scriptFamily: 'IndoPak' }),
    layout(12, 'Mushaf Qatar'),
    layout(13, 'Old Indopak layout', { status: 'legacy', scriptFamily: 'IndoPak' }),
    layout(14, 'KFGQPC V2 layout (Old)', {
      status: 'superseded',
      supersededBy: { id: 10, name: 'KFGQPC V2 layout', type: 'mushaf-layout', toParam: 'kfgqpc-v2-layout' },
    }),
  ],
  pick: 'Use the layout of the printed mushaf that your readers know.',
  comparison: {
    columns: [
      { key: 'script_family', label: 'Script family' },
      { key: 'pages', label: 'Pages' },
      { key: 'lines_per_page', label: 'Lines per page' },
      { key: 'rendering', label: 'Rendering' },
      { key: 'font', label: 'Font' },
      { key: 'status', label: 'Status' },
    ],
    rows: [
      {
        id: 10,
        name: 'KFGQPC V2 layout',
        type: 'mushaf-layout',
        toParam: 'kfgqpc-v2-layout',
        status: 'stable',
        scriptFamily: 'Madani',
        rendering: 'Glyph font for each page',
        pages: 604,
        linesPerPage: 15,
        font: qpcV2,
      },
      {
        id: 13,
        name: 'Old Indopak layout',
        type: 'mushaf-layout',
        toParam: 'old-indopak-layout',
        status: 'legacy',
        scriptFamily: null,
        rendering: null,
        pages: null,
        linesPerPage: null,
        font: null,
      },
    ],
  },
}

// Props of catalog/CatalogPage, shaped like Catalog::ResourcesIndexResource.
export const catalogPageProps: CatalogResourcesIndex = {
  total: 2,
  page: 1,
  pages: 1,
  filters: {
    q: '',
    type: null,
    language: null,
    script: [],
    format: null,
    granularity: null,
    status: null,
    sort: 'popular',
    page: 1,
  },
  results: [
    {
      id: 1,
      name: 'Sahih International',
      type: 'translation',
      toParam: 'sahih-international',
      language: 'English',
      granularity: '1_ayah',
      formats: ['json', 'sqlite'],
      status: 'stable',
      recommended: false,
    },
    {
      id: 3,
      name: 'Tafsir Ibn Kathir',
      type: 'tafsir',
      toParam: 'tafsir-ibn-kathir',
      language: null,
      granularity: 'n_ayah',
      formats: ['json'],
      status: 'stable',
      recommended: false,
    },
  ],
  facets: {
    type: [
      { value: 'translation', count: 1 },
      { value: 'tafsir', count: 1 },
    ],
    language: [{ value: 'en', count: 1 }],
    script: [
      { value: 'madani', count: 2 },
      { value: 'indopak', count: 1 },
    ],
    format: [
      { value: 'json', count: 2 },
      { value: 'sqlite', count: 1 },
    ],
    granularity: [
      { value: '1_ayah', count: 1 },
      { value: 'n_ayah', count: 1 },
    ],
    status: [{ value: 'stable', count: 2 }],
  },
  vocabularies: {
    types: [translation, tafsir],
    languages: [{ key: 'en', name: 'English', nativeName: 'English' }],
    scriptFamilies: [
      { key: 'madani', label: 'Madani' },
      { key: 'indopak', label: 'IndoPak' },
      { key: 'other', label: 'Other scripts' },
    ],
    formats: [
      { key: 'json', label: 'JSON' },
      { key: 'sqlite', label: 'SQLite' },
    ],
    granularities: [
      { key: '1_ayah', label: 'Ayah by ayah' },
      { key: 'n_ayah', label: 'Multiple ayahs' },
    ],
    statuses: [{ key: 'stable', label: 'Stable' }],
    sorts: [
      { key: 'popular', label: 'Most downloaded' },
      { key: 'name', label: 'Name' },
      { key: 'updated', label: 'Recently updated' },
    ],
  },
}

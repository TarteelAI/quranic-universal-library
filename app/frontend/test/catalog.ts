import type {
  CatalogResourceCard,
  CatalogResourcesIndex,
  CatalogResourcesShow,
  CatalogType,
  CatalogTypesShow,
} from '@/types/serializers'

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
      summary: 'English translation of the Quran, ayah by ayah.',
      formats: ['json', 'sqlite'],
      language: 'English',
      granularity: 'Ayah by Ayah',
      status: 'stable',
      scriptFamily: null,
      recommendation: null,
      previewKind: 'text',
      supersededBy: null,
    },
    {
      id: 2,
      name: 'Word by word in Urdu',
      type: 'translation',
      toParam: '2',
      summary: null,
      formats: [],
      language: null,
      granularity: 'Word by word',
      status: 'stable',
      scriptFamily: null,
      recommendation: null,
      previewKind: 'text',
      supersededBy: null,
    },
  ],
  statuses: [
    { key: 'stable', label: 'Stable' },
    { key: 'beta', label: 'Beta' },
    { key: 'legacy', label: 'Legacy' },
    { key: 'superseded', label: 'Superseded' },
  ],
  formats: [
    { key: 'json', label: 'JSON' },
    { key: 'sqlite', label: 'SQLite' },
  ],
  total: 2,
  search: null,
  pick: null,
  guidePath: '/docs/resource-translations',
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
    summary: null,
    formats: ['json'],
    language: null,
    granularity: null,
    status: 'stable',
    scriptFamily: 'Madani',
    recommendation: null,
    previewKind: 'layout',
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
  total: 5,
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
    category: null,
    type: null,
    language: null,
    script: [],
    format: null,
    granularity: null,
    status: null,
    sort: 'popular',
    page: 1,
    view: 'grid',
  },
  groups: null,
  results: [
    {
      id: 1,
      name: 'Sahih International',
      type: 'translation',
      toParam: 'sahih-international',
      summary: 'English translation of the Quran, ayah by ayah.',
      language: 'English',
      granularity: '1_ayah',
      formats: ['json', 'sqlite'],
      status: 'stable',
      recommended: false,
      previewKind: 'text',
    },
    {
      id: 3,
      name: 'Tafsir Ibn Kathir',
      type: 'tafsir',
      toParam: 'tafsir-ibn-kathir',
      summary: null,
      language: null,
      granularity: 'n_ayah',
      formats: ['json'],
      status: 'stable',
      recommended: false,
      previewKind: null,
    },
  ],
  facets: {
    category: [
      { value: 'translation', count: 1 },
      { value: 'tafsir', count: 1 },
    ],
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

// Props of catalog/ResourcePage, shaped like Catalog::ResourcesShowResource: a tafsir with two
// SQLite files and one JSON file, two relation groups (one link drafted) and a changelog.
export const resourcePageProps: CatalogResourcesShow = {
  resource: {
    id: 7,
    name: 'Tafsir Ibn Kathir',
    type: 'tafsir',
    toParam: 'tafsir-ibn-kathir',
    status: 'stable',
    scriptFamily: null,
    language: 'English',
    granularity: 'Ayah by Ayah',
    summary: 'English tafsir, ayah by ayah. JSON and SQLite files.',
    info: '<p>An abridged <strong>English</strong> edition.</p>',
    recommendation: null,
    reviewed: {
      status: true,
      supersededBy: true,
      recommended: true,
      scriptFamily: true,
      rendering: true,
      summary: false,
    },
    supersededBy: null,
  },
  type: tafsir,
  statuses: [
    { key: 'stable', label: 'Stable' },
    { key: 'beta', label: 'Beta' },
    { key: 'legacy', label: 'Legacy' },
    { key: 'superseded', label: 'Superseded' },
  ],
  files: [
    {
      id: 11,
      name: 'simple.sqlite',
      format: 'sqlite',
      formatLabel: 'SQLite',
      byteSize: 5_347_738,
      md5: 'd41d8cd98f00b204e9800998ecf8427e',
    },
    {
      id: 12,
      name: 'simple.json',
      format: 'json',
      formatLabel: 'JSON',
      byteSize: 812,
      md5: '0cc175b9c0f1b6a831c399e269772661',
    },
    {
      id: 13,
      name: 'translation-text-chunk.sqlite',
      format: 'sqlite',
      formatLabel: 'SQLite',
      byteSize: 1_048_576,
      md5: '92eb5ffee6ae2fec3ad71c777531578f',
    },
  ],
  facts: [
    { label: 'Type', value: 'Tafsir' },
    { label: 'Granularity', value: 'Ayah by Ayah' },
    { label: 'Formats', value: 'SQLite, JSON' },
  ],
  worksWith: [
    {
      key: 'requires',
      label: 'Requires',
      links: [
        {
          reviewed: false,
          typeLabel: 'Font',
          resource: { id: 21, name: 'Digital Khatt', type: 'font', toParam: 'digital-khatt' },
        },
      ],
    },
    {
      key: 'pairs_with',
      label: 'Pairs with',
      links: [
        {
          reviewed: true,
          typeLabel: 'Quran script',
          resource: { id: 22, name: 'QPC Hafs', type: 'quran-script', toParam: 'qpc-hafs' },
        },
      ],
    },
  ],
  changelog: [
    {
      id: 31,
      title: 'Fixed footnotes',
      excerpt: 'Footnotes in 2:255 are back.',
      date: '4 March 2026',
      path: '/change_logs/31',
    },
  ],
  licence: null,
  tab: 'preview',
  downloadMode: 'sign_in',
  download: null,
  issueUrl:
    'https://github.com/TarteelAI/quranic-universal-library/issues/new?resource_link=https%3A%2F%2Fqul.tarteel.ai%2Fresources%2Ftafsir%2Ftafsir-ibn-kathir&resource_name=Tafsir+Ibn+Kathir&resource_type=Tafsir&template=content_issue.yml',
  canDownload: true,
  restriction: null,
  updatedOn: '29 December 2023',
  guidePath: '/docs/resource-tafsirs',
}

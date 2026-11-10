import type { CatalogResourcesIndex, CatalogTypesShow } from '@/types/serializers'

const translation = {
  key: 'translation',
  label: 'Translation',
  title: 'Translations',
  summary: 'Ayah by ayah and word by word translations in many languages.',
  description: 'Translations of the Quran in many languages.',
  category: { key: 'translation', label: 'Translation' },
}

const tafsir = {
  key: 'tafsir',
  label: 'Tafsir',
  title: 'Tafsirs',
  summary: 'Short and detailed commentaries.',
  description: 'Commentaries on the Quran in many languages.',
  category: { key: 'tafsir', label: 'Tafsir and commentary' },
}

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
    },
    {
      id: 2,
      name: 'Word by word in Urdu',
      type: 'translation',
      toParam: '2',
      filesCount: 1,
      language: null,
      granularity: 'Word by word',
    },
  ],
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
  facets: { type: [], language: [], script: [], format: [], granularity: [], status: [] },
  vocabularies: {
    types: [translation, tafsir],
    languages: [{ key: 'en', name: 'English', nativeName: 'English' }],
    scriptFamilies: [],
    formats: [{ key: 'json', label: 'JSON' }],
    granularities: [
      { key: '1_ayah', label: 'Ayah by ayah' },
      { key: 'n_ayah', label: 'Multiple ayahs' },
    ],
    statuses: [{ key: 'stable', label: 'Stable' }],
    sorts: [{ key: 'popular', label: 'Most downloaded' }],
  },
}

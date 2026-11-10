import type { CatalogTypesShow } from '@/types/serializers'

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

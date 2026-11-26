import type {
  StartKitCard,
  StartKitsShow,
  StartKitsIndex,
  StartSetupResults,
  StartSetupShow,
} from '@/types/serializers'

import { catalogPageProps } from './catalog'

// Props of start/SetupPage, shaped like Start::SetupShowResource, with no answers yet.
export const setupPageProps: StartSetupShow = {
  goals: [
    {
      key: 'reader',
      label: 'Quran reader app',
      blurb: 'Show the Quran page by page.',
      features: ['mushaf', 'translation', 'nav'],
    },
    { key: 'audio', label: 'Audio and recitation', blurb: 'Play reciters.', features: ['audio', 'nav'] },
  ],
  platforms: [
    { key: 'web', label: 'Web', hint: 'JSON files' },
    { key: 'ios', label: 'iOS', hint: 'SQLite files' },
  ],
  features: [
    { key: 'mushaf', label: 'Mushaf pages' },
    { key: 'audio', label: 'Audio playback' },
    { key: 'translation', label: 'Translation' },
    { key: 'nav', label: 'Juz and hizb navigation' },
  ],
  scripts: [
    { key: 'madani', label: 'Madani (Uthmani)', blurb: 'Read across most of the world.', sample: null },
    { key: 'indopak', label: 'IndoPak', blurb: 'Familiar in South Asia.', sample: null },
  ],
  languages: [
    { key: 'en', name: 'English', count: 38 },
    { key: 'ur', name: 'Urdu', count: 15 },
  ],
  answers: { goals: [], platforms: [], features: [], scripts: [], languages: [], answered: [], step: 0 },
  catalogPages: true,
}

// Props of start/SetupResultsPage, shaped like Start::SetupResultsResource: a reader app with an
// English translation and a need the chosen script has nothing for (a need nothing fits is left out
// on the server).
export const setupResultsProps: StartSetupResults = {
  goals: ['Quran reader app'],
  platforms: ['iOS', 'Android'],
  formats: ['SQLite'],
  editPath: '/start?goal=reader&platform=ios,android&feature=translation,mushaf&script=madani&lang=en',
  sections: [
    {
      key: 'translation-en',
      label: 'Translation in English',
      type: 'translation',
      total: 9,
      catalogPath: '/resources?granularity=1_ayah&language=en&type=translation',
      scripts: [],
      results: [catalogPageProps.results[0]],
    },
    {
      key: 'tajweed',
      label: 'Tajweed text',
      type: 'quran-script',
      total: 0,
      catalogPath: '/resources?q=tajweed&script=indopak&type=quran-script',
      scripts: ['IndoPak'],
      results: [],
    },
  ],
  vocabularies: {
    ...catalogPageProps.vocabularies,
    types: [
      ...catalogPageProps.vocabularies.types,
      { key: 'quran-script', label: 'Quran script', category: { key: 'script', label: 'Script and fonts' } },
    ],
  },
}

// Shaped like Start::KitCardResource.
export const kitCard: StartKitCard = {
  key: 'madani-reader',
  title: 'Madani reader',
  tag: 'Mushaf app',
  blurb: 'The KFGQPC V2 page layout with its font and text.',
  path: '/kits/madani-reader',
  resources: [
    { name: 'KFGQPC V2 layout', category: 'layout' },
    { name: 'Saheeh International', category: 'translation' },
  ],
}

// Props of start/KitsPage, shaped like Start::KitsIndexResource.
export const kitsPageProps: StartKitsIndex = {
  kits: [kitCard, { ...kitCard, key: 'recitation', title: 'Recitation with highlighting', path: '/kits/recitation' }],
}

// Props of start/KitPage, shaped like Start::KitShowResource: one item with an alternative, one
// without.
export const kitPageProps: StartKitsShow = {
  key: 'madani-reader',
  title: 'Madani reader',
  description: 'Everything a mushaf app in the Madani script needs.',
  setupPath: '/start?goal=reader&platform=android,ios&feature=mushaf,translation,nav&script=madani&lang=en',
  kitsPath: '/kits',
  typeCounts: ['1 translation', '1 tafsir'],
  items: [
    {
      need: 'English translation',
      why: 'Clear, literal English, ayah by ayah.',
      resource: catalogPageProps.results[0],
      alternative: { id: 9, name: 'The Clear Quran', type: 'translation', toParam: 'the-clear-quran' },
    },
    {
      need: 'Navigation',
      why: 'The first and last ayah of each juz.',
      resource: catalogPageProps.results[1],
      alternative: null,
    },
  ],
  vocabularies: catalogPageProps.vocabularies,
  catalogPages: true,
  downloadMode: 'sign_in',
}

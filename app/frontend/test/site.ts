import type { SiteApp, SiteAppsIndex, SiteHomeShow } from '@/types/serializers'

// Shaped like Site::AppResource.
const quranwbw: SiteApp = {
  id: 'quranwbw',
  name: 'QuranWBW',
  url: 'https://quranwbw.com',
  kind: 'Word by word',
  description: 'Read, listen to and learn the Quran word by word, with translations in many languages.',
  featured: true,
  iconUrl: '/app-icons/quranwbw.png',
  platforms: ['Web'],
  uses: [{ key: 'translation', label: 'Translation', category: 'translation' }],
}

const quranValidator: SiteApp = {
  id: 'quran-validator',
  name: 'Quran Validator',
  url: 'https://quranvalidator.com',
  kind: 'Verse checker',
  description: 'Checks Quran verses quoted in LLM output against the real text and flags misquotes.',
  featured: true,
  iconUrl: null,
  platforms: ['Library', 'Web'],
  uses: [{ key: 'quran-script', label: 'Quran script', category: 'script' }],
}

const nimaz: SiteApp = {
  id: 'nimaz',
  name: 'Nimaz',
  url: 'https://nimaz.arshadshah.com',
  kind: 'Islamic companion',
  description: 'Offline, ad-free Islamic companion app with a mushaf reader.',
  featured: false,
  iconUrl: '/app-icons/nimaz.png',
  platforms: ['Android'],
  uses: [{ key: 'mushaf-layout', label: 'Mushaf layout', category: 'layout' }],
}

const waqfah: SiteApp = {
  id: 'waqfah',
  name: 'Waqfah',
  url: 'https://f-droid.org/packages/dev.shrekbytes.waqfah.fdroid',
  kind: 'Ayah reminder',
  description: 'Shows an ayah before opening a chosen app, so you can read or skip and carry on.',
  featured: false,
  iconUrl: '/app-icons/waqfah.png',
  platforms: ['Android'],
  uses: [
    { key: 'quran-script', label: 'Quran script', category: 'script' },
    { key: 'translation', label: 'Translation', category: 'translation' },
  ],
}

const SUBMIT_URL = 'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=app_submission.yml'

// Shaped like Site::HomeShowResource.
export const homePageProps: SiteHomeShow = {
  resources: 547,
  languages: 94,
  recitations: 133,
  categories: [
    { key: 'audio', label: 'Audio', hint: 'Recitations with word timing', count: 133 },
    { key: 'translation', label: 'Translation', hint: 'Many languages, word by word too', count: 214 },
  ],
  samples: [
    { type: 'recitation', category: 'audio', count: 133, name: 'Mishari Rashid al-Afasy', toParam: 'afasy' },
    { type: 'translation', category: 'translation', count: 190, name: 'Saheeh International', toParam: 'saheeh' },
  ],
  showcase: [quranwbw, nimaz, waqfah, quranValidator],
  appsCount: 23,
  submitUrl: SUBMIT_URL,
  tools: [
    {
      label: 'Ayah translations',
      href: '/ayah_translations',
      description: 'Fix typos in many languages.',
      category: 'translation',
      icon: 'languages',
      external: false,
      inertia: false,
    },
  ],
  catalogPages: true,
  appsPage: true,
  contentPages: true,
}

// Shaped like Site::AppsIndexResource, unfiltered.
export const appsPageProps: SiteAppsIndex = {
  apps: [quranwbw, quranValidator, nimaz, waqfah],
  total: 4,
  filters: { platform: null, type: null },
  platforms: [
    { key: 'ios', label: 'iOS' },
    { key: 'android', label: 'Android' },
    { key: 'web', label: 'Web' },
    { key: 'library', label: 'Library' },
  ],
  types: [
    { key: 'mushaf-layout', label: 'Mushaf layout' },
    { key: 'quran-script', label: 'Quran script' },
    { key: 'translation', label: 'Translation' },
  ],
  submissionTypes: [
    { key: 'recitation', label: 'Recitation' },
    { key: 'mushaf-layout', label: 'Mushaf layout' },
    { key: 'quran-script', label: 'Quran script' },
    { key: 'translation', label: 'Translation' },
  ],
  catalogPages: true,
}

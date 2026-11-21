import type { AccountProfilesEdit, AccountProfilesShow } from '@/types/serializers'

// Shaped like Account::ProfilesShowResource: the downloads tab, filtered to translations.
export const profilePageProps: AccountProfilesShow = {
  tab: 'downloads',
  page: 1,
  pages: 1,
  catalog: true,
  person: {
    name: 'Fake Reader',
    initials: 'FR',
    email: 'reader@example.test',
    memberSince: 'November 2026',
    about: '<p>Building a study app.</p>',
  },
  counts: { downloads: 2, contributions: 60, resources: 1, requests: 2 },
  filter: {
    param: 'download_type',
    value: 'translation',
    options: [
      { key: 'tafsir', label: 'Tafsir' },
      { key: 'translation', label: 'Translation' },
    ],
  },
  downloads: [
    {
      id: 1,
      type: 'Translation',
      name: 'Saheeh International',
      path: '/resources/translation/saheeh-international',
      date: '20 November 2026',
      updateAvailable: false,
    },
    { id: 2, type: 'Translation', name: 'Hindi translation', path: null, date: '1 July 2026', updateAvailable: true },
  ],
  contributions: null,
  accesses: null,
  requests: null,
}

// Shaped like Account::ProfilesEditResource.
export const settingsPageProps: AccountProfilesEdit = {
  firstName: 'Fake',
  lastName: 'Reader',
  about: 'Building a study app.',
  email: 'reader@example.test',
  memberSince: '10 November 2026',
  emailStatus: 'confirmed',
  unconfirmedEmail: null,
}

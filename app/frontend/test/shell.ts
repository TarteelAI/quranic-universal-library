import type { Auth, SharedProps, SiteNav, SiteNavLink } from '@/types/serializers'

function link(label: string, href: string, options: Partial<SiteNavLink> = {}): SiteNavLink {
  return { label, href, description: null, category: null, icon: null, external: false, inertia: false, ...options }
}

// The site navigation, shaped like SiteNavResource: one new-page menu and one old-page menu.
export const nav: SiteNav = {
  home: link('Home', '/'),
  menus: [
    {
      label: 'Resources',
      href: '/resources',
      overview: 'Browse all resources',
      inertia: true,
      dense: false,
      groups: [
        {
          heading: 'Resource types',
          wide: true,
          tools: false,
          links: [
            link('Translations', '/resources/translation', {
              inertia: true,
              category: 'translation',
              description: 'Ayah by ayah and word by word translations in many languages.',
            }),
            link('Tafsirs', '/resources/tafsir', { inertia: true, category: 'tafsir' }),
          ],
        },
      ],
      aside: [
        { heading: 'Jump to', wide: false, tools: false, links: [link('How to download', '/docs/downloading-data')] },
      ],
    },
    {
      label: 'Contribute',
      href: '/tools',
      overview: 'All contribution tools',
      inertia: false,
      dense: true,
      groups: [
        {
          heading: 'Mushaf & scripts',
          wide: false,
          tools: true,
          links: [
            link('Tajweed rules', '/tajweed_words', { icon: 'palette', description: 'Rules marked on each letter.' }),
          ],
        },
        {
          heading: 'Translations & tafsir',
          wide: false,
          tools: true,
          links: [
            link('Ayah translations', '/translations', {
              icon: 'languages',
              description: 'Fix typos in many languages.',
            }),
            link('Tafsirs', '/tafsirs', { icon: 'book-open-text', description: 'Tafsir text and ayah ranges.' }),
          ],
        },
      ],
      aside: [
        {
          heading: 'Help improve the data',
          wide: false,
          tools: false,
          links: [link('Changelog', '/change_logs')],
        },
        {
          heading: 'Community',
          wide: false,
          tools: false,
          links: [link('GitHub', 'https://github.com/TarteelAI/quranic-universal-library', { external: true })],
        },
      ],
    },
  ],
  search: link('Search resources', '/resources', { inertia: true }),
  footer: [
    {
      heading: 'Resources',
      wide: false,
      tools: false,
      links: [link('All resources', '/resources', { inertia: true }), link('All docs', '/docs')],
    },
  ],
  request: link(
    'Request a resource',
    'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=resource_request.yml',
    { external: true },
  ),
  docsSearch: false,
  bundle: true,
}

export const signedInAuth: Auth = { user: { initials: 'FR', name: 'Fake' } }

// Shared props of a signed-out visitor (SharedPropsResource).
export const sharedProps: SharedProps = { auth: { user: null }, nav }

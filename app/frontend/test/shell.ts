import type { Auth, SharedProps, SiteNav, SiteNavLink } from '@/types/serializers'

function link(label: string, href: string, options: Partial<SiteNavLink> = {}): SiteNavLink {
  return { label, href, description: null, category: null, external: false, inertia: false, ...options }
}

// The site navigation, shaped like SiteNavResource: one new-page menu and one old-page menu.
export const nav: SiteNav = {
  menus: [
    {
      label: 'Resources',
      href: '/resources',
      overview: 'Browse all resources',
      inertia: true,
      groups: [
        {
          heading: 'Resource types',
          wide: true,
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
      aside: [{ heading: 'Jump to', wide: false, links: [link('How to download', '/docs/downloading-data')] }],
    },
    {
      label: 'Contribute',
      href: '/tools',
      overview: 'All contribution tools',
      inertia: false,
      groups: [{ heading: 'Contribution tools', wide: true, links: [link('Tajweed rules', '/tajweed_words')] }],
      aside: [
        {
          heading: 'Community',
          wide: false,
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
      links: [link('All resources', '/resources', { inertia: true }), link('All docs', '/docs')],
    },
  ],
  request: link(
    'Request a resource',
    'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=resource_request.yml',
    { external: true },
  ),
}

export const signedInAuth: Auth = { user: { initials: 'FR', name: 'Fake' } }

// Shared props of a signed-out visitor (SharedPropsResource).
export const sharedProps: SharedProps = { auth: { user: null }, nav }

import { router } from '@inertiajs/react'
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react'
import * as React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { nav } from '@/test/shell'
import type { CatalogSpotlightResult, SiteNav, SiteNavGroup, SiteNavLink } from '@/types/serializers'

import { SiteHeader } from './chrome'
import { forgetPopularResources, navSearchItems, Spotlight } from './spotlight'

const result = (id: number, name: string, options: Partial<CatalogSpotlightResult> = {}): CatalogSpotlightResult => ({
  id,
  name,
  type: 'tafsir',
  typeLabel: 'Tafsir',
  category: 'tafsir',
  toParam: `tafsir-${id}`,
  language: 'English',
  formats: ['JSON', 'SQLite'],
  ...options,
})

const POPULAR = [
  result(1, 'Ibn Kathir'),
  result(2, 'Saheeh International', {
    type: 'translation',
    typeLabel: 'Translation',
    category: 'translation',
    toParam: 'saheeh',
  }),
]

let fetchMock: ReturnType<typeof vi.fn>

// Answers /spotlight like Catalog::SpotlightController: popular resources without a query.
function answer(url: string) {
  const q = new URL(url, 'http://localhost').searchParams.get('q')
  const matches = (r: CatalogSpotlightResult) => `${r.name} ${r.typeLabel}`.toLowerCase().includes(q!.toLowerCase())
  const results = q ? POPULAR.filter(matches) : POPULAR
  return new Response(JSON.stringify({ results, total: results.length }), { status: 200 })
}

// A response the test sends when it chooses.
function deferred() {
  let respond: (response: Response) => void = () => {}
  const promise = new Promise<Response>((resolve) => (respond = resolve))
  return { promise, respond: (response: Response) => act(async () => respond(response)) }
}

const popularCalls = () => fetchMock.mock.calls.filter((call) => call[0] === '/spotlight')
const queryCalls = () => fetchMock.mock.calls.filter((call) => String(call[0]).includes('?q='))

beforeEach(() => {
  forgetPopularResources()
  fetchMock = vi.fn((url: string) => Promise.resolve(answer(url)))
  vi.stubGlobal('fetch', fetchMock)
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

function Harness() {
  const [open, setOpen] = React.useState(false)
  return <Spotlight open={open} onOpenChange={setOpen} />
}

const dialog = () => screen.getByRole('dialog', { name: 'Search QUL' })
const field = () => within(dialog()).getByRole('combobox', { name: 'Search QUL' })
const group = (name: string) => within(dialog()).getByRole('group', { name })

function openSpotlight(options: Parameters<typeof renderPage>[1] = { props: {} }) {
  renderPage(Harness, options)
  fireEvent.click(screen.getByRole('button', { name: 'Search resources' }))
}

describe('Spotlight', () => {
  it('fetches nothing until it is opened', () => {
    renderPage(Harness, { props: {} })

    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('opens on the popular resources, with type icons and formats, and the quick links', async () => {
    openSpotlight()

    expect(field()).toBe(document.activeElement)
    const popular = await waitFor(() => group('Popular resources'))
    expect(fetchMock.mock.calls.map((call) => call[0])).toEqual(['/spotlight'])
    const first = within(popular).getAllByRole('option')[0]
    expect(first.textContent).toContain('Ibn Kathir')
    expect(first.textContent).toContain('Tafsir · English · JSON, SQLite')
    expect(first.querySelector('svg')).not.toBeNull()
    expect(
      within(group('Quick links'))
        .getAllByRole('option')
        .map((o) => o.textContent),
    ).toEqual(['Browse all resources', 'All contribution tools'])
    expect(within(dialog()).getByText('to move')).toBeDefined()
    expect(within(dialog()).queryByRole('status')).toBeNull()
  })

  it('closes with its Esc button', () => {
    openSpotlight()

    fireEvent.click(within(dialog()).getByRole('button', { name: 'Close search' }))
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('groups a query into resources, pages and tools, and leaves out docs', async () => {
    openSpotlight()

    fireEvent.change(field(), { target: { value: 'ibn' } })
    await waitFor(() => group('Resources'))
    expect(fetchMock.mock.calls.at(-1)?.[0]).toBe('/spotlight?q=ibn')
    expect(within(group('Resources')).getByRole('option').textContent).toContain('Ibn Kathir')
    expect(within(dialog()).getAllByRole('option').at(-1)?.textContent).toBe('All 1 results for “ibn”')

    fireEvent.change(field(), { target: { value: 'tafsir' } })
    await waitFor(() =>
      expect(within(dialog()).getAllByRole('option').at(-1)?.textContent).toBe('All 1 results for “tafsir”'),
    )
    expect(within(group('Pages')).getByRole('option').textContent).toContain('Tafsirs')

    fireEvent.change(field(), { target: { value: 'tajweed' } })
    await waitFor(() => group('Tools'))
    expect(within(group('Tools')).getByRole('option').textContent).toContain('Tajweed rules')

    fireEvent.change(field(), { target: { value: 'download' } })
    await waitFor(() =>
      expect(within(dialog()).getByRole('status').textContent).toBe('No resources, pages or tools match “download”.'),
    )
    expect(within(dialog()).queryByText('How to download')).toBeNull()
  })

  describe('the popular resources', () => {
    const close = () => fireEvent.click(within(dialog()).getByRole('button', { name: 'Close search' }))
    const reopen = () => fireEvent.click(screen.getByRole('button', { name: 'Search resources' }))

    it('are asked for once: a second open shows them with no request', async () => {
      openSpotlight()
      await waitFor(() => group('Popular resources'))
      close()
      reopen()

      expect(within(group('Popular resources')).getAllByRole('option')).toHaveLength(POPULAR.length)
      expect(popularCalls()).toHaveLength(1)
    })

    it('share one request between two opens before it answers', async () => {
      const popular = deferred()
      fetchMock.mockImplementation(() => popular.promise)
      openSpotlight()
      close()
      reopen()
      await popular.respond(answer('/spotlight'))

      await waitFor(() => group('Popular resources'))
      expect(popularCalls()).toHaveLength(1)
    })

    it('are asked for again on the next open after a failed request', async () => {
      fetchMock.mockImplementationOnce(() => Promise.resolve(new Response('', { status: 500 })))
      openSpotlight()
      await waitFor(() => expect(popularCalls()).toHaveLength(1))
      expect(within(dialog()).queryByRole('group', { name: 'Popular resources' })).toBeNull()
      close()
      reopen()

      await waitFor(() => group('Popular resources'))
      expect(popularCalls()).toHaveLength(2)
    })
  })

  it('aborts the request of an older query', async () => {
    openSpotlight()

    fireEvent.change(field(), { target: { value: 'ib' } })
    await waitFor(() => expect(queryCalls()).toHaveLength(1))
    fireEvent.change(field(), { target: { value: 'ibn' } })
    await waitFor(() => expect(queryCalls()).toHaveLength(2))
    expect((queryCalls()[0][1] as RequestInit).signal?.aborted).toBe(true)
    expect((queryCalls()[1][1] as RequestInit).signal?.aborted).toBe(false)
  })

  it('on open, Enter goes to the catalog, however soon it is pressed', () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    openSpotlight()

    fireEvent.keyDown(field(), { key: 'Enter' })
    expect(visit).toHaveBeenCalledWith('/resources')
  })

  it('moves with the arrow keys and opens a resource as an Inertia visit while the catalog serves it', async () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    openSpotlight()
    await waitFor(() => group('Popular resources'))

    const browse = within(dialog()).getByRole('option', { name: 'Browse all resources' })
    expect(browse.getAttribute('aria-selected')).toBe('true')
    fireEvent.keyDown(field(), { key: 'ArrowUp' })
    const saheeh = within(group('Popular resources')).getByRole('option', { name: /Saheeh/ })
    expect(saheeh.getAttribute('aria-selected')).toBe('true')
    expect(field().getAttribute('aria-activedescendant')).toBe(saheeh.id)
    fireEvent.keyDown(field(), { key: 'Enter' })

    expect(visit).toHaveBeenCalledWith('/resources/translation/saheeh')
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  describe('the highlight with a query', () => {
    const selected = () => within(dialog()).getByRole('option', { selected: true })

    // Each query is answered when the test says so.
    function answerQueriesLater() {
      const pending: ReturnType<typeof deferred>[] = []
      fetchMock.mockImplementation((url: string) => {
        if (!url.includes('?q=')) return Promise.resolve(answer(url))
        const later = deferred()
        pending.push(later)
        return later.promise
      })
      let answered = 0
      // Answers the next query request, once the spotlight has sent it.
      return async (url: string) => {
        await waitFor(() => expect(pending.length).toBeGreaterThan(answered))
        answered = pending.length
        await pending.at(-1)!.respond(answer(url))
      }
    }

    it('moves an untouched highlight to the top resource when the results arrive', async () => {
      const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
      const respond = answerQueriesLater()
      openSpotlight()

      fireEvent.change(field(), { target: { value: 'tafsir' } })
      expect(selected().textContent).toContain('Tafsirs')
      await respond('/spotlight?q=tafsir')

      await waitFor(() => expect(within(group('Resources')).getByRole('option', { selected: true })).toBeDefined())
      expect(selected().textContent).toContain('Ibn Kathir')
      fireEvent.keyDown(field(), { key: 'Enter' })
      expect(visit).toHaveBeenCalledWith('/resources/tafsir/tafsir-1')
    })

    it('keeps a highlight the visitor placed when the results arrive, until a new query', async () => {
      const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
      const respond = answerQueriesLater()
      openSpotlight()

      fireEvent.change(field(), { target: { value: 'tafsir' } })
      fireEvent.keyDown(field(), { key: 'ArrowUp' })
      expect(selected().textContent).toBe('All results for “tafsir”')
      await respond('/spotlight?q=tafsir')

      await waitFor(() => group('Resources'))
      expect(selected().textContent).toBe('All 1 results for “tafsir”')

      fireEvent.change(field(), { target: { value: 'ibn' } })
      await respond('/spotlight?q=ibn')
      await waitFor(() => group('Resources'))
      expect(selected().textContent).toContain('Ibn Kathir')
      fireEvent.keyDown(field(), { key: 'Enter' })
      expect(visit).toHaveBeenCalledWith('/resources/tafsir/tafsir-1')
    })
  })

  for (const [failure, respond] of [
    ['a non-OK answer', () => Promise.resolve(new Response('', { status: 500 }))],
    ['a network error', () => Promise.reject(new TypeError('Failed to fetch'))],
  ] as const) {
    it(`ends the search with a message on ${failure}, and keeps pages, tools and the catalog search`, async () => {
      const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
      fetchMock.mockImplementation((url: string) => (url.includes('?q=') ? respond() : Promise.resolve(answer(url))))
      openSpotlight()

      fireEvent.change(field(), { target: { value: 'tafsir' } })
      await waitFor(() =>
        expect(within(dialog()).getByRole('status').textContent).toBe(
          'Resources could not be loaded. Pages, tools and the full search still work.',
        ),
      )
      expect(within(group('Pages')).getByRole('option', { name: /Tafsirs/ })).toBeDefined()
      const all = within(dialog()).getAllByRole('option').at(-1)!
      expect(all.textContent).toBe('All results for “tafsir”')
      fireEvent.click(all)
      expect(visit).toHaveBeenCalledWith('/resources?q=tafsir')
    })
  }

  it('loads a resource in full when the catalog page group is off, and an old page in full', async () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    const assign = vi.fn()
    vi.spyOn(window, 'location', 'get').mockReturnValue({ ...window.location, assign })
    openSpotlight({ props: {}, shared: { nav: { ...nav, search: { ...nav.search, inertia: false } } } })
    await waitFor(() => group('Popular resources'))

    fireEvent.click(within(group('Popular resources')).getAllByRole('option')[0])
    expect(assign).toHaveBeenCalledWith('/resources/tafsir/tafsir-1')

    fireEvent.click(screen.getByRole('button', { name: 'Search resources' }))
    fireEvent.click(within(group('Quick links')).getByRole('option', { name: 'All contribution tools' }))
    expect(assign).toHaveBeenCalledWith('/tools')
    expect(visit).not.toHaveBeenCalled()
  })

  it('opens an external link in a new tab', async () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null)
    openSpotlight()

    fireEvent.change(field(), { target: { value: 'github' } })
    fireEvent.click(await waitFor(() => within(group('Pages')).getByRole('option', { name: /GitHub/ })))
    expect(open).toHaveBeenCalledWith('https://github.com/TarteelAI/quranic-universal-library', '_blank', 'noreferrer')
  })
})

const navLink = (label: string, href: string, options: Partial<SiteNavLink> = {}): SiteNavLink => ({
  label,
  href,
  description: null,
  category: null,
  icon: null,
  external: false,
  inertia: false,
  ...options,
})
const navGroup = (heading: string, links: SiteNavLink[], tools = false): SiteNavGroup => ({
  heading,
  wide: false,
  tools,
  links,
})

// Shaped like SiteNav builds it: a tool address also linked from the Resources menu, /tools in
// three places, FAQ and Credits in the Contribute menu's "About contributing" group.
const [resourcesMenu, contributeMenu] = nav.menus
const siteNav: SiteNav = {
  ...nav,
  menus: [
    {
      ...resourcesMenu,
      aside: [
        ...resourcesMenu.aside,
        navGroup('Spot a mistake?', [
          navLink('Fix a translation', '/translations'),
          navLink('All contribution tools', '/tools'),
        ]),
      ],
    },
    {
      ...contributeMenu,
      groups: [
        ...contributeMenu.groups,
        navGroup('About contributing', [
          navLink('FAQ', '/faq', { icon: 'circle-help' }),
          navLink('Credits', '/credits', { icon: 'award' }),
        ]),
      ],
    },
  ],
  footer: [...nav.footer, navGroup('Contribute', [navLink('Contribution tools', '/tools'), navLink('FAQ', '/faq')])],
}

describe('navSearchItems', () => {
  it('lists the tools of the tools groups, then the pages, once each and without docs', () => {
    const items = navSearchItems(nav)

    expect(items.map((item) => [item.group, item.label, item.href])).toEqual([
      ['Tools', 'Tajweed rules', '/tajweed_words'],
      ['Tools', 'Ayah translations', '/translations'],
      ['Tools', 'Tafsirs', '/tafsirs'],
      ['Pages', 'Home', '/'],
      ['Pages', 'Browse all resources', '/resources'],
      ['Pages', 'Translations', '/resources/translation'],
      ['Pages', 'Tafsirs', '/resources/tafsir'],
      ['Pages', 'All contribution tools', '/tools'],
      ['Pages', 'Changelog', '/change_logs'],
      ['Pages', 'GitHub', 'https://github.com/TarteelAI/quranic-universal-library'],
    ])
  })

  it('reads a menu with more fields', () => {
    const extended = { ...nav, menus: nav.menus.map((menu) => ({ ...menu, badge: 'new' })) }

    expect(navSearchItems(extended)).toHaveLength(navSearchItems(nav).length)
  })

  it('makes FAQ and Credits pages, keeps a tool address as the tool, and lists /tools once', () => {
    const items = navSearchItems(siteNav)
    const byLabel = (label: string) => items.filter((item) => item.label === label)

    expect(byLabel('FAQ').map((item) => item.group)).toEqual(['Pages'])
    expect(byLabel('Credits').map((item) => item.group)).toEqual(['Pages'])
    expect(byLabel('Ayah translations').map((item) => [item.group, item.href])).toEqual([['Tools', '/translations']])
    expect(byLabel('Fix a translation')).toEqual([])
    expect(items.filter((item) => item.href === '/tools')).toHaveLength(1)
  })
})

describe('Spotlight on the site navigation', () => {
  it('finds a tool by its name, with its own icon, and FAQ under pages', async () => {
    openSpotlight({ props: {}, shared: { nav: siteNav } })

    fireEvent.change(field(), { target: { value: 'ayah translations' } })
    const tool = await waitFor(() => within(group('Tools')).getByRole('option', { name: /Ayah translations/ }))
    expect(tool.querySelector('svg.lucide-languages')).not.toBeNull()

    fireEvent.change(field(), { target: { value: 'faq' } })
    await waitFor(() => within(group('Pages')).getByRole('option', { name: /FAQ/ }))
    expect(within(dialog()).queryByRole('group', { name: 'Tools' })).toBeNull()
  })
})

describe('SiteHeader phone sheet', () => {
  it('shows the lockup and a search field that opens the spotlight', async () => {
    renderPage(() => <SiteHeader />, { props: {} })

    fireEvent.click(screen.getByRole('button', { name: 'Menu' }))
    const sheet = screen.getByRole('dialog', { name: 'Menu' })
    expect(within(sheet).getByRole('link', { name: 'QUL home' }).textContent).toContain('Quranic Universal Library')
    await act(async () => fireEvent.click(within(sheet).getByRole('button', { name: 'Search resources' })))

    expect(screen.queryByRole('dialog', { name: 'Menu' })).toBeNull()
    await waitFor(() => expect(field()).toBe(document.activeElement))
  })
})

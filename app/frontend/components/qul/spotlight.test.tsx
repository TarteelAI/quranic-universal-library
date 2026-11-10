import { router } from '@inertiajs/react'
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react'
import * as React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { nav } from '@/test/shell'
import type { CatalogSpotlightResult } from '@/types/serializers'

import { SiteHeader } from './chrome'
import { navSearchItems, Spotlight } from './spotlight'

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
  const results = q ? POPULAR.filter((r) => r.name.toLowerCase().includes(q.toLowerCase())) : POPULAR
  return new Response(JSON.stringify({ results, total: results.length }), { status: 200 })
}

beforeEach(() => {
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
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock.mock.calls[0][0]).toBe('/spotlight')
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
      expect(within(dialog()).getAllByRole('option').at(-1)?.textContent).toBe('All 0 results for “tafsir”'),
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

  it('aborts the request of an older query', async () => {
    openSpotlight()
    await waitFor(() => group('Popular resources'))

    fireEvent.change(field(), { target: { value: 'ib' } })
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2))
    fireEvent.change(field(), { target: { value: 'ibn' } })
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(3))
    expect((fetchMock.mock.calls[1][1] as RequestInit).signal?.aborted).toBe(true)
    expect((fetchMock.mock.calls[2][1] as RequestInit).signal?.aborted).toBe(false)
  })

  it('moves with the arrow keys and opens a resource as an Inertia visit while the catalog serves it', async () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    openSpotlight()
    await waitFor(() => group('Popular resources'))

    const options = within(dialog()).getAllByRole('option')
    expect(options[0].getAttribute('aria-selected')).toBe('true')
    fireEvent.keyDown(field(), { key: 'ArrowDown' })
    expect(options[1].getAttribute('aria-selected')).toBe('true')
    expect(field().getAttribute('aria-activedescendant')).toBe(options[1].id)
    fireEvent.keyDown(field(), { key: 'Enter' })

    expect(visit).toHaveBeenCalledWith('/resources/translation/saheeh')
    expect(screen.queryByRole('dialog')).toBeNull()
  })

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

describe('navSearchItems', () => {
  it('lists each page and tool once, without docs, and reads a menu with more fields', () => {
    const extended = { ...nav, menus: nav.menus.map((menu) => ({ ...menu, badge: 'new' })) }
    const items = navSearchItems(extended)

    expect(items.map((item) => [item.group, item.label])).toEqual([
      ['Pages', 'Home'],
      ['Pages', 'Browse all resources'],
      ['Pages', 'Translations'],
      ['Pages', 'Tafsirs'],
      ['Tools', 'All contribution tools'],
      ['Tools', 'Tajweed rules'],
      ['Pages', 'GitHub'],
    ])
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

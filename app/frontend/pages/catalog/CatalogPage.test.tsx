import { router } from '@inertiajs/react'
import { act, fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { catalogPageProps } from '@/test/catalog'
import { renderPage } from '@/test/inertia'
import type { CatalogResourcesIndex } from '@/types/serializers'

import CatalogPage from './CatalogPage'

const SEARCH_PROPS = ['filters', 'results', 'facets', 'total', 'page', 'pages']

const filtered: CatalogResourcesIndex = {
  ...catalogPageProps,
  filters: { ...catalogPageProps.filters, q: 'sahih', script: ['madani', 'indopak'], format: 'json', sort: 'name' },
  pages: 3,
  page: 2,
}

describe('catalog/CatalogPage', () => {
  afterEach(() => {
    vi.restoreAllMocks()
    vi.useRealTimers()
  })

  it('shows the result count and one card per result, linking to its detail page', () => {
    renderPage(CatalogPage, { props: catalogPageProps })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Resources2')
    const cards = within(screen.getByRole('list', { name: 'Resources' })).getAllByRole('article')
    expect(cards).toHaveLength(2)
    expect(screen.getByRole('link', { name: 'Tafsir Ibn Kathir' }).getAttribute('href')).toBe(
      '/resources/tafsir/tafsir-ibn-kathir',
    )
    expect(screen.getByText('Translation · English · Ayah by ayah')).toBeDefined()
    expect(screen.getByText('JSON · SQLite')).toBeDefined()
  })

  it('shows the filters of the URL in the controls, as chips and in the paging links', () => {
    renderPage(CatalogPage, { props: filtered })

    expect(screen.getByRole<HTMLInputElement>('searchbox', { name: 'Search resources' }).value).toBe('sahih')
    expect(screen.getByRole<HTMLSelectElement>('combobox', { name: 'Sort' }).value).toBe('name')
    const rail = within(screen.getByRole('complementary', { name: 'Filters' }))
    for (const name of [/^Madani/, /^IndoPak/, /^JSON/])
      expect(rail.getByRole('checkbox', { name }).getAttribute('aria-checked')).toBe('true')
    expect(rail.getByRole('checkbox', { name: /^Translation/ }).getAttribute('aria-checked')).toBe('false')
    const chips = within(screen.getByRole('group', { name: 'Active filters' }))
    expect(chips.getAllByRole('button', { name: /^Remove/ }).map((chip) => chip.getAttribute('aria-label'))).toEqual([
      'Remove “sahih”',
      'Remove Madani',
      'Remove IndoPak',
      'Remove JSON',
    ])
    const pages = within(screen.getByRole('navigation', { name: 'Pages' }))
    expect(pages.getByRole('link', { name: 'Next' }).getAttribute('href')).toBe(
      '/resources?q=sahih&script[]=madani&script[]=indopak&format=json&sort=name&page=3',
    )
    expect(pages.getByRole('link', { name: 'Previous' }).getAttribute('href')).toBe(
      '/resources?q=sahih&script[]=madani&script[]=indopak&format=json&sort=name',
    )
  })

  it('reloads only the search props when a filter changes, adding a history entry', () => {
    const get = vi.spyOn(router, 'get').mockImplementation(() => {})
    renderPage(CatalogPage, { props: filtered })

    fireEvent.click(
      within(screen.getByRole('complementary', { name: 'Filters' })).getByRole('checkbox', { name: /^IndoPak/ }),
    )
    expect(get).toHaveBeenCalledWith(
      '/resources?q=sahih&script[]=madani&format=json&sort=name',
      {},
      { only: SEARCH_PROPS, preserveState: true, preserveScroll: true, replace: false },
    )

    fireEvent.click(screen.getByRole('button', { name: 'Remove JSON' }))
    expect(get).toHaveBeenLastCalledWith(
      '/resources?q=sahih&script[]=madani&script[]=indopak&sort=name',
      {},
      expect.objectContaining({ replace: false }),
    )
  })

  it('searches once the typing pauses, replacing the history entry', () => {
    vi.useFakeTimers()
    const get = vi.spyOn(router, 'get').mockImplementation(() => {})
    renderPage(CatalogPage, { props: catalogPageProps })

    const field = screen.getByRole('searchbox', { name: 'Search resources' })
    fireEvent.change(field, { target: { value: 'ur' } })
    fireEvent.change(field, { target: { value: 'urdu' } })
    expect(get).not.toHaveBeenCalled()
    act(() => vi.advanceTimersByTime(300))

    expect(get).toHaveBeenCalledTimes(1)
    expect(get).toHaveBeenCalledWith('/resources?q=urdu', {}, expect.objectContaining({ replace: true }))
  })

  it('shows the empty state and the request card when nothing matches', () => {
    renderPage(CatalogPage, { props: { ...filtered, results: [], total: 0, pages: 1, page: 1 } })

    expect(screen.getByText('Nothing matches this search')).toBeDefined()
    expect(screen.getByRole('button', { name: 'Clear all filters' })).toBeDefined()
    expect(screen.getByRole('link', { name: 'Request a resource' }).getAttribute('href')).toBe(
      'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=resource_request.yml',
    )
  })
})

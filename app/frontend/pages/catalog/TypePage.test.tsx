import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { layoutPageProps, typePageProps } from '@/test/catalog'
import { renderPage } from '@/test/inertia'

import TypePage from './TypePage'

describe('catalog/TypePage', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('shows the type title, its description and the resource count', () => {
    renderPage(TypePage, { props: typePageProps })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Translations2')
    expect(screen.getByText('Translations of the Quran in many languages.')).toBeDefined()
  })

  it('shows one card per resource, linking to its detail page', () => {
    renderPage(TypePage, { props: typePageProps })

    const cards = within(screen.getByRole('list', { name: 'Translations' })).getAllByRole('article')
    expect(cards).toHaveLength(2)
    expect(screen.getByRole('link', { name: 'Sahih International' }).getAttribute('href')).toBe(
      '/resources/translation/sahih-international',
    )
    expect(screen.getByText('Translation · English · Ayah by Ayah')).toBeDefined()
    expect(screen.getByText('Translation · Word by word')).toBeDefined()
    expect(screen.getByText('1 file')).toBeDefined()
  })

  it('opens a detail page from a card with an in-app visit', () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    renderPage(TypePage, { props: typePageProps })

    fireEvent.click(screen.getByRole('link', { name: 'Sahih International' }))
    expect(visit).toHaveBeenCalledWith('/resources/translation/sahih-international', expect.anything())
  })

  it("links to the type's format docs, a page outside the new pages, with a plain link", () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    renderPage(TypePage, { props: typePageProps })

    const docs = screen.getByRole('link', { name: 'Translation format docs' })
    expect(docs.getAttribute('href')).toBe('/docs/resource-translations')
    fireEvent.click(docs)
    expect(visit).not.toHaveBeenCalled()
  })

  it('shows no format docs link for a type without a guide', () => {
    renderPage(TypePage, { props: { ...typePageProps, guidePath: null } })

    expect(screen.queryByRole('link', { name: /format docs/ })).toBeNull()
  })

  it('links to every type page and marks the current one', () => {
    renderPage(TypePage, { props: typePageProps })

    const nav = screen.getByRole('navigation', { name: 'Other resource types' })
    expect(within(nav).getByRole('link', { name: 'Tafsirs' }).getAttribute('href')).toBe('/resources/tafsir')
    expect(within(nav).getByRole('link', { name: 'Translations' }).getAttribute('aria-current')).toBe('page')
  })

  it('says so when no resource of the type is published', () => {
    renderPage(TypePage, { props: { ...typePageProps, resources: [] } })

    expect(screen.getByText('No resources of this type are published yet.')).toBeDefined()
  })

  it('shows no "Which one should I pick?" block and no older versions for a type without status data', () => {
    renderPage(TypePage, { props: typePageProps })

    expect(screen.queryByRole('heading', { name: 'Which one should I pick?' })).toBeNull()
    expect(screen.queryByText(/Older versions/)).toBeNull()
    expect(screen.queryByRole('table')).toBeNull()
  })

  it('puts recommended resources first, marks a drafted one as not yet reviewed, and collapses older ones', () => {
    renderPage(TypePage, { props: layoutPageProps })

    expect(screen.getByRole('heading', { level: 2, name: 'Which one should I pick?' })).toBeDefined()
    expect(screen.getByText('Use the layout of the printed mushaf that your readers know.')).toBeDefined()

    const recommended = within(screen.getByRole('list', { name: 'Recommended' })).getAllByRole('article')
    expect(recommended.map((card) => within(card).getByRole('heading').textContent)).toEqual([
      'KFGQPC V2 layout',
      'Indopak 15 lines',
    ])
    expect(within(recommended[0]).getByText('Recommended')).toBeDefined()
    expect(within(recommended[0]).queryByText(/not yet reviewed/)).toBeNull()
    expect(within(recommended[1]).getByText('Suggested, not yet reviewed')).toBeDefined()

    const current = within(screen.getByRole('list', { name: 'Mushaf layouts' })).getAllByRole('article')
    expect(current.map((card) => within(card).getByRole('heading').textContent)).toEqual(['Mushaf Qatar'])
    expect(within(current[0]).getByText('Mushaf layout · Madani')).toBeDefined()

    const older = screen.getByText(/Older versions \(2\)/).closest('details')
    expect(older?.open).toBe(false)
    // jsdom does not toggle <details> on a summary click; the browser test covers that.
    older!.open = true
    const olderCards = within(screen.getByRole('list', { name: 'Older versions' })).getAllByRole('article')
    expect(olderCards).toHaveLength(2)
    expect(within(olderCards[0]).getByText('Legacy')).toBeDefined()
    const superseded = olderCards[1]
    expect(within(superseded).getByText('Superseded')).toBeDefined()
    expect(within(superseded).getByRole('link', { name: 'Replaced by KFGQPC V2 layout' }).getAttribute('href')).toBe(
      '/resources/mushaf-layout/kfgqpc-v2-layout',
    )
  })

  it('shows every card once across the groups', () => {
    const { container } = renderPage(TypePage, { props: layoutPageProps })

    expect(container.querySelectorAll('article')).toHaveLength(layoutPageProps.resources.length)
  })

  it('shows the comparison table with typed facts, linking each layout and its font', () => {
    renderPage(TypePage, { props: layoutPageProps })

    const table = screen.getByRole('table', { name: 'Comparison' })
    const headers = within(table)
      .getAllByRole('columnheader')
      .map((cell) => cell.textContent)
    expect(headers).toEqual([
      'Mushaf layout',
      'Script family',
      'Pages',
      'Lines per page',
      'Rendering',
      'Font',
      'Status',
    ])
    const [, first, second] = within(table).getAllByRole('row')
    expect(
      within(first)
        .getAllByRole('cell')
        .map((cell) => cell.textContent),
    ).toEqual(['KFGQPC V2 layout', 'Madani', '604', '15', 'Glyph font for each page', 'QPC V2 Font', 'Stable'])
    expect(within(first).getByRole('link', { name: 'QPC V2 Font' }).getAttribute('href')).toBe(
      '/resources/font/qpc-v2-font',
    )
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    fireEvent.click(within(first).getByRole('link', { name: 'KFGQPC V2 layout' }))
    expect(visit).toHaveBeenCalledWith('/resources/mushaf-layout/kfgqpc-v2-layout', expect.anything())
    fireEvent.click(within(first).getByRole('link', { name: 'QPC V2 Font' }))
    expect(visit).toHaveBeenLastCalledWith('/resources/font/qpc-v2-font', expect.anything())
    expect(
      within(second)
        .getAllByRole('cell')
        .map((cell) => cell.textContent),
    ).toEqual(['Old Indopak layout', '–', '–', '–', '–', '–', 'Legacy'])
  })
})

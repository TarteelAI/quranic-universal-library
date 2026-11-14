import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { changelogProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import ChangelogPage from './ChangelogPage'

describe('content/ChangelogPage', () => {
  it('lists each entry with its date, excerpt and resource', () => {
    renderPage(ChangelogPage, { props: changelogProps, url: '/changelog?page=2' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Changelog')
    const entries = within(screen.getByRole('list', { name: 'Changelog' })).getAllByRole('listitem')
    expect(entries).toHaveLength(2)
    const first = within(entries[0])
    expect(first.getByRole('link', { name: 'Updated the Diyanet Turkish translation' }).getAttribute('href')).toBe(
      '/changelog/31',
    )
    expect(first.getByText('4 March 2026')).toBeTruthy()
    expect(first.getByRole('link', { name: 'Diyanet Isleri' }).getAttribute('href')).toBe(
      '/resources/translation/diyanet-isleri',
    )
    // An unpublished resource is named without a link.
    const second = within(entries[1])
    expect(second.getByText('QPC v1 glyphs').tagName).toBe('SPAN')
    expect(second.queryByRole('link', { name: 'QPC v1 glyphs' })).toBeNull()
  })

  it('links to the newer and older pages, page 1 without a query', () => {
    renderPage(ChangelogPage, { props: changelogProps, url: '/changelog?page=2' })

    const pager = within(screen.getByRole('navigation', { name: 'Pages' }))
    expect(pager.getByRole('link', { name: /Newer/ }).getAttribute('href')).toBe('/changelog')
    expect(pager.getByRole('link', { name: /Older/ }).getAttribute('href')).toBe('/changelog?page=3')
    expect(pager.getByText('Page 2 of 3')).toBeTruthy()
  })

  it('has no pager for a single page, and says when there are no entries', () => {
    renderPage(ChangelogPage, { props: { entries: [], page: 1, pages: 1 }, url: '/changelog' })

    expect(screen.queryByRole('navigation', { name: 'Pages' })).toBeNull()
    expect(screen.getByText('No changes are published yet.')).toBeTruthy()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(ChangelogPage, { props: changelogProps })

    expect(logged).toEqual([])
    unmount()
  })
})

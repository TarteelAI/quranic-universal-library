import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { changelogEntryProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import ChangelogEntryPage from './ChangelogEntryPage'

describe('content/ChangelogEntryPage', () => {
  it('shows the title, date, resource link and body', () => {
    const { container } = renderPage(ChangelogEntryPage, { props: changelogEntryProps, url: '/changelog/31' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Updated the Diyanet Turkish translation')
    expect(screen.getByText('4 March 2026').tagName).toBe('TIME')
    expect(screen.getByRole('link', { name: 'Diyanet Isleri' }).getAttribute('href')).toBe(
      '/resources/translation/diyanet-isleri',
    )
    expect(screen.getByRole('link', { name: 'Changelog' }).getAttribute('href')).toBe('/changelog')
    expect(container.querySelector('article li strong')?.textContent).toBe('6,218')
  })

  it('names a resource that is not published without a link', () => {
    const entry = { ...changelogEntryProps.entry, resource: { name: 'QPC v1 glyphs', path: null } }
    renderPage(ChangelogEntryPage, { props: { entry }, url: '/changelog/31' })

    expect(screen.getByText('QPC v1 glyphs').tagName).toBe('SPAN')
    expect(screen.queryByRole('link', { name: 'QPC v1 glyphs' })).toBeNull()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(ChangelogEntryPage, { props: changelogEntryProps })

    expect(logged).toEqual([])
    unmount()
  })
})

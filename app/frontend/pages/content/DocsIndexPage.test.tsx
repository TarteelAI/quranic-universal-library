import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { docsIndexProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import DocsIndexPage from './DocsIndexPage'

describe('content/DocsIndexPage', () => {
  it('shows one card per category, with its top-level pages', () => {
    renderPage(DocsIndexPage, { props: docsIndexProps, url: '/docs' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('QUL documentation')
    const cards = screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.closest('li')!)
    expect(cards).toHaveLength(2)
    const download = within(cards[0])
    expect(download.getByRole('link', { name: 'Download Resources' }).getAttribute('href')).toBe(
      '/docs/download-resources',
    )
    // The overview is the card's title and the tutorials sit under Tutorials, so neither is listed.
    expect(download.getAllByRole('link').map((link) => link.textContent)).toEqual([
      'Download Resources',
      'Datasets',
      'Tutorials',
    ])
    expect(within(cards[1]).getByText('Coming soon')).toBeDefined()
  })

  it('marks the index as the current page in the side navigation', () => {
    renderPage(DocsIndexPage, { props: docsIndexProps, url: '/docs' })

    const [sideNav] = screen.getAllByRole('navigation', { name: 'Docs' })
    expect(within(sideNav).getByRole('link', { current: 'page' }).textContent).toBe('All docs')
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(DocsIndexPage, { props: docsIndexProps })

    expect(logged).toEqual([])
    unmount()
  })
})

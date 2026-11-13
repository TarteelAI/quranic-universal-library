import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { toolsProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import ToolsPage from './ToolsPage'

describe('content/ToolsPage', () => {
  it('shows each group with its tools as links to the old tool pages', () => {
    renderPage(ToolsPage, { props: toolsProps, url: '/tools' })

    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'Translations & tafsir',
      'Mushaf & scripts',
    ])
    const mushaf = within(screen.getByRole('region', { name: 'Mushaf & scripts' }))
    expect(mushaf.getByText('Page layouts, Quran scripts and tajweed.')).toBeDefined()
    expect(mushaf.getAllByRole('link').map((link) => link.getAttribute('href'))).toEqual([
      '/mushaf_layouts',
      '/tajweed_words',
    ])
    expect(mushaf.getByRole('link', { name: /Mushaf layouts/ }).textContent).toContain(
      'Build and proofread Mushaf page layouts.',
    )
    expect(screen.getByRole('link', { name: 'How to contribute data' }).getAttribute('href')).toBe(
      '/docs/contribute-data',
    )
  })

  it('shows no access state or progress', () => {
    renderPage(ToolsPage, { props: toolsProps, url: '/tools' })

    expect(screen.queryByText(/request access|you have access|%/i)).toBeNull()
    expect(screen.queryByRole('progressbar')).toBeNull()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(ToolsPage, { props: toolsProps })

    expect(logged).toEqual([])
    unmount()
  })
})

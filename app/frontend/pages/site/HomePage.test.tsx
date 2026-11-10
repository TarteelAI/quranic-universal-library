import { screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { homePageProps } from '@/test/site'

import HomePage from './HomePage'

describe('site/HomePage', () => {
  beforeEach(() => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json({ stargazers_count: 1234 }))
  })
  afterEach(() => vi.restoreAllMocks())

  it('shows the catalog counts in the hero', () => {
    renderPage(HomePage, { props: homePageProps })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe(
      'Verified data for builders impacting the Ummah.',
    )
    const stats = screen.getAllByRole('definition').map((value) => value.textContent)
    expect(stats).toEqual(['547', '94', '133'])
    expect(screen.getAllByRole('term').map((term) => term.textContent)).toEqual([
      'resources',
      'languages',
      'recitations',
    ])
  })

  it('links each category to its type pages, with their counts', () => {
    renderPage(HomePage, { props: homePageProps })

    const translation = within(screen.getByRole('region', { name: 'Translation' }))
    expect(translation.getByText('214')).toBeDefined()
    const link = translation.getByRole('link', { name: /Transliterations/ })
    expect(link.getAttribute('href')).toBe('/resources/transliteration')
    expect(link.textContent).toContain('24')
  })

  it('shows the apps showcase, with the directory link only while the apps page exists', () => {
    const { unmount } = renderPage(HomePage, { props: homePageProps })

    expect(screen.getByText(/^20\+ readers/)).toBeDefined()
    expect(screen.getByRole('link', { name: /QuranWBW/ }).getAttribute('href')).toBe('https://quranwbw.com')
    expect(screen.getByRole('link', { name: 'See the apps' }).getAttribute('href')).toBe('/apps')
    expect(screen.getByRole('link', { name: 'Submit your app' }).getAttribute('href')).toBe(homePageProps.submitUrl)
    unmount()

    renderPage(HomePage, { props: { ...homePageProps, appsPage: false } })
    expect(screen.queryByRole('link', { name: 'See the apps' })).toBeNull()
  })

  it('shows the star count from GitHub once it loads', async () => {
    renderPage(HomePage, { props: homePageProps })

    expect(await screen.findByText('1,234')).toBeDefined()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(HomePage, { props: homePageProps })

    expect(logged).toEqual([])
    unmount()
  })
})

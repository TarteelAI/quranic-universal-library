import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { homePageProps } from '@/test/site'

import HomePage from './HomePage'

describe('site/HomePage', () => {
  beforeEach(() => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json({ stargazers_count: 1234 }))
  })
  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

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

  it('links each category row to the catalog filtered to it, with its hint and count', () => {
    renderPage(HomePage, { props: homePageProps })

    const row = screen.getByRole('link', { name: /^Translation/ })
    expect(row.getAttribute('href')).toBe('/resources?category=translation')
    expect(row.textContent).toContain('Many languages, word by word too')
    expect(row.textContent).toContain('214')
    // The rows replace the type links.
    expect(screen.queryByRole('link', { name: /Transliterations/ })).toBeNull()
  })

  it('shows a tab per sample and loads only the open tab preview, once it is on screen', () => {
    const reload = vi.spyOn(router, 'reload').mockImplementation(() => {})
    // Every observed element is on screen at once.
    vi.stubGlobal(
      'IntersectionObserver',
      class {
        constructor(private callback: IntersectionObserverCallback) {}
        observe(target: Element) {
          this.callback([{ target, isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver)
        }
        disconnect() {}
      },
    )
    renderPage(HomePage, { props: homePageProps })

    expect(screen.getAllByRole('tab').map((tab) => tab.textContent)).toEqual(['Recitations', 'Translations'])
    const panel = screen.getByRole('tabpanel')
    expect(within(panel).getByRole('heading', { name: 'Recitations, timed to the text' })).toBeDefined()
    expect(within(panel).getByText(/^133 recitations/)).toBeDefined()
    expect(
      within(panel)
        .getByRole('link', { name: /Browse recitations/ })
        .getAttribute('href'),
    ).toBe('/resources/recitation')
    expect(within(panel).getByRole('link', { name: 'Mishari Rashid al-Afasy' }).getAttribute('href')).toBe(
      '/resources/recitation/afasy',
    )
    expect(reload).toHaveBeenCalledTimes(1)
    expect(reload).toHaveBeenCalledWith(expect.objectContaining({ only: ['recitationPreview'] }))

    // Radix opens a tab on mouse down.
    fireEvent.mouseDown(screen.getByRole('tab', { name: 'Translations' }), { button: 0 })
    expect(reload).toHaveBeenLastCalledWith(expect.objectContaining({ only: ['translationPreview'] }))
    expect(reload).toHaveBeenCalledTimes(2)
  })

  it('shows a loaded preview without asking for it again', () => {
    const reload = vi.spyOn(router, 'reload').mockImplementation(() => {})
    renderPage(HomePage, { props: { ...homePageProps, recitationPreview: null } })

    expect(within(screen.getByRole('tabpanel')).getByTestId('no-preview')).toBeDefined()
    expect(reload).not.toHaveBeenCalled()
  })

  it('shows the contribution tools and links the tools overview', () => {
    renderPage(HomePage, { props: homePageProps })

    const tools = within(screen.getByRole('list', { name: 'Contribution tools' }))
    expect(tools.getByRole('link', { name: /Ayah translations/ }).getAttribute('href')).toBe('/ayah_translations')
    expect(screen.getByRole('link', { name: 'See all tools' }).getAttribute('href')).toBe('/tools')
  })

  it('shows the apps showcase, with the directory and submission links only while the apps page exists', () => {
    const { unmount } = renderPage(HomePage, { props: homePageProps })

    expect(screen.getByText(/^20\+ readers/)).toBeDefined()
    expect(screen.getByRole('link', { name: /QuranWBW/ }).getAttribute('href')).toBe('https://quranwbw.com')
    expect(screen.getByRole('link', { name: 'See the apps' }).getAttribute('href')).toBe('/apps')
    expect(screen.getByRole('link', { name: 'Submit your app' }).getAttribute('href')).toBe('/apps?submit=1')
    unmount()

    renderPage(HomePage, { props: { ...homePageProps, appsPage: false } })
    expect(screen.queryByRole('link', { name: 'See the apps' })).toBeNull()
    expect(screen.queryByRole('link', { name: 'Submit your app' })).toBeNull()
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

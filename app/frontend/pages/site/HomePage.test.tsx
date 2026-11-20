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
    expect(stats).toEqual(['547', '94', '57'])
    expect(screen.getAllByRole('term').map((term) => term.textContent)).toEqual([
      'resources',
      'languages',
      'contributors',
    ])
  })

  it('gives each category one card, linked to the catalog filtered to it, with its hint and count', () => {
    renderPage(HomePage, { props: homePageProps })

    const cards = screen.getAllByTestId('library-card')
    expect(cards.map((card) => card.dataset.category)).toEqual(['audio', 'translation', 'topics'])
    const card = within(cards[1])
    expect(card.getByRole('link', { name: 'Translation' }).getAttribute('href')).toBe('/resources?category=translation')
    expect(cards[1].textContent).toContain('Many languages, word by word too')
    expect(cards[1].textContent).toContain('214')
    expect(card.getByRole('link', { name: 'Saheeh International' }).getAttribute('href')).toBe(
      '/resources/translation/saheeh',
    )
    // The narrow card names no sample; no card shows a preview before it loads.
    expect(within(cards[2]).queryByRole('link', { name: 'Topics' })).toBeNull()
    expect(screen.queryByTestId('sample-preview')).toBeNull()
    expect(screen.queryByRole('tab')).toBeNull()
  })

  it("loads each sampled card's preview once it is on screen", () => {
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

    expect(reload.mock.calls.map(([options]) => options?.only)).toEqual([
      ['recitationPreview'],
      ['translationPreview'],
      ['ayahTopicsPreview'],
    ])
  })

  it('plays the recitation an ayah at a time, steps through the translation and shows a topic with its ayahs', () => {
    const play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue()
    renderPage(HomePage, {
      props: {
        ...homePageProps,
        recitationPreview: {
          kind: 'recitation',
          granularity: 'surah',
          highlights: true,
          tracks: ['https://audio.test/001.mp3'],
          surah: { number: 1, name: 'Al-Fatihah', versesCount: 7 },
          surahs: [],
          ayahs: [
            { key: '1:1', number: 1, text: 'بِسْمِ', track: 0, from: 0, to: 5000 },
            { key: '1:2', number: 2, text: 'ٱلْحَمْدُ', track: 0, from: 5000, to: 9000 },
          ],
        },
        translationPreview: {
          kind: 'text',
          granularity: 'ayah',
          from: 1,
          to: 2,
          locale: { code: 'en', direction: 'ltr' },
          surah: { number: 1, name: 'Al-Fatihah', versesCount: 7 },
          surahs: [],
          entries: [
            { key: '1:1', text: 'In the name', truncated: false, ayahs: [], footnotes: [], words: [] },
            { key: '1:2', text: 'All praise', truncated: false, ayahs: [], footnotes: [], words: [] },
          ],
        },
        ayahTopicsPreview: {
          kind: 'records',
          limit: 10,
          surah: null,
          surahs: [],
          locale: { code: 'en', direction: 'ltr' },
          records: [
            {
              key: '1',
              label: 'Patience',
              arabic: null,
              text: null,
              html: null,
              truncated: false,
              tags: ['2:45', '2:153', '3:200', '8:46', '11:115', '40 more ayahs'],
            },
          ],
        },
      },
    })

    const audio = within(screen.getAllByTestId('library-card')[0])
    expect(audio.getByText('بِسْمِ')).toBeDefined()
    fireEvent.click(audio.getByRole('button', { name: 'Play from ayah 1:2' }))
    expect(play).toHaveBeenCalledTimes(1)
    expect(audio.getAllByRole('button', { name: /^Play from ayah/ })).toHaveLength(2)

    const translation = within(screen.getAllByTestId('library-card')[1])
    expect(translation.getByText('All praise')).toBeDefined()
    fireEvent.click(translation.getByRole('button', { name: 'Next ayah' }))
    expect(translation.getByText('In the name')).toBeDefined()

    const topics = within(screen.getAllByTestId('library-card')[2])
    const ayahs = within(topics.getByRole('list', { name: 'Ayahs about Patience' })).getAllByRole('listitem')
    expect(ayahs.map((ayah) => ayah.textContent)).toEqual(['2:45', '2:153', '3:200'])
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

  it('opens the guided setup from the hero, the closing banner and each goal, and links the kits', () => {
    renderPage(HomePage, { props: homePageProps })

    expect(screen.getAllByRole('link', { name: 'Start building' }).map((link) => link.getAttribute('href'))).toEqual([
      '/start',
      '/start',
    ])
    expect(screen.queryByRole('link', { name: 'Read the docs' })).toBeNull()
    expect(screen.getByRole('link', { name: /^Quran reader app/ }).getAttribute('href')).toBe('/start?goal=reader')
    expect(screen.getByRole('link', { name: /^Audio and recitation/ }).getAttribute('href')).toBe('/start?goal=audio')
    expect(screen.getByRole('link', { name: /Madani reader/ }).getAttribute('href')).toBe('/kits/madani-reader')
    expect(screen.getByRole('link', { name: 'All kits' }).getAttribute('href')).toBe('/kits')
  })

  it('shows no goals, kits or setup buttons with the start group off', () => {
    renderPage(HomePage, { props: { ...homePageProps, goals: [], kits: [], startPages: false } })

    expect(screen.queryByRole('heading', { name: 'What are you building?' })).toBeNull()
    expect(screen.queryByRole('heading', { name: 'Start from a kit' })).toBeNull()
    expect(screen.queryByRole('link', { name: 'Start building' })).toBeNull()
    expect(screen.getAllByRole('link', { name: 'Browse the library' })).toHaveLength(2)
    expect(screen.getByRole('link', { name: 'Read the docs' }).getAttribute('href')).toBe('/docs/getting-started')
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

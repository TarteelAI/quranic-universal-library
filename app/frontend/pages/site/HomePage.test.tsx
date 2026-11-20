import { router } from '@inertiajs/react'
import { act, fireEvent, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { layoutPreview } from '@/test/previews'
import { homePageProps } from '@/test/site'
import type { SiteSampleCard } from '@/types/serializers'

import HomePage from './HomePage'

function translationCard(
  label: string,
  name: string,
  toParam: string,
  code: string,
  direction: 'ltr' | 'rtl',
  text: string,
): SiteSampleCard {
  return {
    label,
    name,
    toParam,
    preview: {
      kind: 'text',
      granularity: 'ayah',
      locale: { code, direction },
      entry: {
        key: '1:2',
        text,
        truncated: false,
        ayahs: [{ key: '1:2', text: 'ٱلْحَمْدُ' }],
        footnotes: [],
        words: [],
      },
    },
  }
}

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
    // No card shows a preview, or the sample its preview names, before it loads.
    expect(screen.queryByTestId('sample-preview')).toBeNull()
    expect(card.queryByRole('link', { name: 'Saheeh International' })).toBeNull()
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
          kind: 'cards',
          cards: [
            translationCard('English', 'Saheeh International', 'saheeh', 'en', 'ltr', 'All praise'),
            translationCard('Urdu', 'Junagarhi', 'junagarhi', 'ur', 'rtl', 'سب تعریف'),
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
    // The preview names its sample, linked to the sample's page; the narrow card names none.
    const source = audio.getByRole('link', { name: 'Mishari Rashid al-Afasy' })
    expect(source.getAttribute('href')).toBe('/resources/recitation/afasy')
    expect(screen.getAllByTestId('sample-preview')[0].contains(source)).toBe(true)
    expect(within(screen.getAllByTestId('library-card')[2]).queryByRole('link', { name: 'Topics' })).toBeNull()
    fireEvent.click(audio.getByRole('button', { name: 'Play from ayah 1:2' }))
    expect(play).toHaveBeenCalledTimes(1)
    expect(audio.getAllByRole('button', { name: /^Play from ayah/ })).toHaveLength(2)

    // One translation at a time, named and linked; the others keep their place, hidden.
    const translationWell = screen.getAllByTestId('library-card')[1]
    const translation = within(translationWell)
    const shown = () => translationWell.querySelector('[aria-hidden="false"] [lang]')
    expect(shown()?.textContent).toBe('All praise')
    expect(translation.getByRole('link', { name: 'Saheeh International' }).getAttribute('href')).toBe(
      '/resources/translation/saheeh',
    )
    fireEvent.click(translation.getByRole('button', { name: 'Urdu' }))
    expect(shown()?.textContent).toBe('سب تعریف')
    expect(shown()?.getAttribute('dir')).toBe('rtl')
    expect(translation.getByRole('button', { name: 'Urdu' }).getAttribute('aria-pressed')).toBe('true')
    expect(translation.getByRole('link', { name: 'Junagarhi' })).toBeDefined()

    const topics = within(screen.getAllByTestId('library-card')[2])
    const ayahs = within(topics.getByRole('list', { name: 'Ayahs about Patience' })).getAllByRole('listitem')
    expect(ayahs.map((ayah) => ayah.textContent)).toEqual(['2:45', '2:153', '3:200'])
  })

  it('goes through the translations on its own, and stops while the card is hovered or once one is picked', () => {
    vi.useFakeTimers()
    renderPage(HomePage, {
      props: {
        ...homePageProps,
        translationPreview: {
          kind: 'cards',
          cards: [
            translationCard('English', 'Saheeh International', 'saheeh', 'en', 'ltr', 'All praise'),
            translationCard('French', 'Montada', 'montada', 'fr', 'ltr', 'Louange à Allah'),
            translationCard('Urdu', 'Junagarhi', 'junagarhi', 'ur', 'rtl', 'سب تعریف'),
          ],
        },
      },
    })
    const card = screen.getAllByTestId('library-card')[1]
    const language = () => card.querySelector('[data-language]')!.getAttribute('data-language')
    expect(language()).toBe('en')
    act(() => vi.advanceTimersByTime(4000))
    expect(language()).toBe('fr')

    fireEvent.pointerEnter(card)
    act(() => vi.advanceTimersByTime(8000))
    expect(language()).toBe('fr')
    fireEvent.pointerLeave(card)
    act(() => vi.advanceTimersByTime(4000))
    expect(language()).toBe('ur')

    fireEvent.click(within(card).getByRole('button', { name: 'English' }))
    act(() => vi.advanceTimersByTime(12000))
    expect(language()).toBe('en')
    vi.useRealTimers()
  })

  it('shows the scripts side by side, a tafsir excerpt and three surahs with their data', () => {
    const scriptCard = (label: string, toParam: string, rendering: 'text' | 'html', text: string): SiteSampleCard => ({
      label,
      name: `${label} script`,
      toParam,
      preview: {
        kind: 'script',
        granularity: 'ayah',
        rendering,
        fontCode: null,
        fonts: [
          { family: toParam, perPage: false, sources: [{ url: `https://cdn.test/${toParam}.woff2`, format: 'woff2' }] },
        ],
        ayah: { key: '1:2', number: 2, text, font: toParam, words: [] },
      },
    })
    renderPage(HomePage, {
      props: {
        ...homePageProps,
        categories: [
          { key: 'script', label: 'Script and fonts', hint: 'Quran text and fonts', count: 56 },
          { key: 'tafsir', label: 'Tafsir', hint: 'Commentaries', count: 114 },
          { key: 'metadata', label: 'Metadata', hint: 'Surah data', count: 8 },
        ],
        samples: [
          { type: 'quran-script', category: 'script', name: 'QPC Hafs', toParam: 'qpc-hafs' },
          { type: 'tafsir', category: 'tafsir', name: 'Ibn Kathir', toParam: 'ibn-kathir' },
          { type: 'quran-metadata', category: 'metadata', name: 'Surah names', toParam: 'surah-names' },
        ],
        quranScriptPreview: {
          kind: 'cards',
          cards: [
            scriptCard('Madani', 'qpc-hafs', 'text', 'ٱلْحَمْدُ لِلَّهِ'),
            scriptCard('Tajweed', 'qpc-tajweed', 'html', 'ٱلْحَمْدُ <rule class="ham_wasl">ٱ</rule>'),
          ],
        },
        tafsirPreview: {
          kind: 'text',
          granularity: 'ayah',
          from: 1,
          to: 1,
          locale: { code: 'en', direction: 'ltr' },
          surah: { number: 1, name: 'Al-Fatihah', versesCount: 7 },
          surahs: [],
          entries: [
            {
              key: '1:1',
              text: '<h2>The Opener</h2><p>This Surah is called Al-Fatihah.</p>',
              truncated: true,
              ayahs: [{ key: '1:1', text: 'بِسْمِ ٱللَّهِ' }],
              footnotes: [],
              words: [],
            },
          ],
        },
        quranMetadataPreview: {
          kind: 'records',
          limit: 10,
          surah: null,
          surahs: [],
          locale: { code: 'en', direction: 'ltr' },
          records: [1, 2, 3, 4].map((number) => ({
            key: String(number),
            label: `${number}. Surah ${number}`,
            arabic: 'سورة',
            text: `${number} ayahs, revealed in Makkah`,
            html: null,
            truncated: false,
            tags: [],
          })),
        },
      },
    })

    const [script, tafsir, metadata] = screen.getAllByTestId('library-card')
    // All three are one column wide.
    for (const card of [script, tafsir, metadata]) expect(card.parentElement!.className).not.toContain('md:col-span-2')

    // Each script in its own font, the tajweed rules kept for their colours; the fonts' rules on the page.
    const lines = script.querySelectorAll('[data-script]')
    expect([...lines].map((line) => line.getAttribute('data-script'))).toEqual(['Madani', 'Tajweed'])
    expect(lines[0].querySelector('span[style]')!.getAttribute('style')).toContain('qpc-hafs')
    expect(lines[1].querySelector('.tajweed rule.ham_wasl')).not.toBeNull()
    expect(script.querySelector('style')!.textContent).toContain('https://cdn.test/qpc-tajweed.woff2')

    const excerpt = within(tafsir)
    expect(excerpt.getByText('This Surah is called Al-Fatihah.')).toBeDefined()
    expect(excerpt.getByRole('link', { name: 'Ibn Kathir' }).getAttribute('href')).toBe('/resources/tafsir/ibn-kathir')

    const surahs = within(metadata).getAllByRole('listitem')
    expect(surahs.map((surah) => surah.textContent)).toEqual([
      '1. Surah 1سورة1 ayahs, revealed in Makkah',
      '2. Surah 2سورة2 ayahs, revealed in Makkah',
      '3. Surah 3سورة3 ayahs, revealed in Makkah',
    ])
  })

  it('shows a layout as a tall card: the page, its count, and the sample it is from', () => {
    renderPage(HomePage, {
      props: {
        ...homePageProps,
        categories: [{ key: 'layout', label: 'Mushaf layouts', hint: 'Printed mushaf page layouts', count: 12 }],
        samples: [{ type: 'mushaf-layout', category: 'layout', name: 'KFGQPC V2', toParam: 'v2' }],
        mushafLayoutPreview: layoutPreview,
      },
    })

    const [card] = screen.getAllByTestId('library-card')
    expect(card.parentElement!.className).toContain('md:row-span-4')
    const preview = within(screen.getByTestId('sample-preview'))
    expect(preview.getByText('Page 2 of 604')).toBeDefined()
    expect(preview.getByRole('link', { name: 'KFGQPC V2' }).getAttribute('href')).toBe('/resources/mushaf-layout/v2')
  })

  it('keeps the ayah just recited through the pause before the next, and fills its step through it', () => {
    // jsdom plays nothing: the position is a clock the test sets, read on each animation frame.
    vi.useFakeTimers({ toFake: ['requestAnimationFrame', 'cancelAnimationFrame'] })
    let position = 0
    vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(function (this: HTMLMediaElement) {
      this.dispatchEvent(new Event('play'))
      return Promise.resolve()
    })
    vi.spyOn(HTMLMediaElement.prototype, 'currentTime', 'get').mockImplementation(() => position / 1000)
    vi.spyOn(HTMLMediaElement.prototype, 'currentTime', 'set').mockImplementation(() => {})
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
            { key: '1:1', number: 1, text: 'بِسْمِ', track: 0, from: 0, to: 4000 },
            { key: '1:2', number: 2, text: 'ٱلْحَمْدُ', track: 0, from: 4200, to: 8000 },
            { key: '1:3', number: 3, text: 'ٱلرَّحْمَـٰنِ', track: 0, from: 8200, to: 12000 },
          ],
        },
      },
    })
    const card = screen.getAllByTestId('library-card')[0]
    const at = (ms: number) => {
      position = ms
      act(() => vi.advanceTimersToNextFrame())
    }
    const fill = (key: string) =>
      (
        within(card)
          .getByRole('button', { name: `Play from ayah ${key}` })
          .querySelector('span span') as HTMLElement
      ).style.width

    // The ayah on screen; one fading out is hidden from assistive technology.
    const shown = () => [...card.querySelectorAll('[lang="ar"] > p:not([aria-hidden])')].map((p) => p.textContent)

    fireEvent.click(within(card).getByRole('button', { name: 'Play Surah Al-Fatihah' }))
    at(6000)
    expect(card.querySelector('[data-active-ayah]')?.getAttribute('data-active-ayah')).toBe('1:2')
    // In the pause after 1:2, 1:2 stays (the card used to show 1:1 here) and its step keeps filling.
    at(8100)
    expect(card.querySelector('[data-active-ayah]')?.getAttribute('data-active-ayah')).toBe('1:2')
    expect(shown()).toEqual(['ٱلْحَمْدُ'])
    expect(fill('1:2')).toBe('97.5%')
    at(8200)
    expect(card.querySelector('[data-active-ayah]')?.getAttribute('data-active-ayah')).toBe('1:3')
    expect(fill('1:2')).toBe('100%')
    expect(fill('1:3')).toBe('0%')
    expect(shown()).toEqual(['ٱلرَّحْمَـٰنِ'])
    vi.useRealTimers()
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

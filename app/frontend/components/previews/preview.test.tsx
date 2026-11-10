import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { fontPreview, layoutPreview, scriptPreview } from '@/test/previews'

import type { PreviewNavigation } from './navigation'
import { Preview } from './preview'

function navigation(): PreviewNavigation {
  return { navigate: vi.fn(), showView: vi.fn(), loading: false }
}

// jsdom has no FontFaceSet: each test says whether the font loads.
function fontsLoad(result: 'loaded' | 'failed') {
  const load = vi.fn(() => (result === 'loaded' ? Promise.resolve([{}]) : Promise.reject(new Error('NetworkError'))))
  Object.defineProperty(document, 'fonts', { value: { load }, configurable: true })
  return load
}

function css() {
  return Array.from(document.querySelectorAll('style'))
    .map((style) => style.innerHTML)
    .join('\n')
}

describe('Preview', () => {
  beforeEach(() => fontsLoad('loaded'))
  afterEach(() => vi.restoreAllMocks())

  describe('a mushaf layout page', () => {
    it('draws the lines in the page font, with the font rules of this page only', async () => {
      render(<Preview preview={layoutPreview} navigation={navigation()} />)

      const page = screen.getByTestId('mushaf-page')
      expect(page.style.fontFamily).toBe('"v2-p2"')
      expect(page.querySelectorAll('[data-line]')).toHaveLength(3)
      expect(page.querySelector('[data-bismillah]')).not.toBeNull()
      expect(page.querySelector('[data-word="102"]')?.className).toBe('text-[blue]')
      await waitFor(() => expect(page.dataset.fontStatus).toBe('loaded'))

      const rules = css()
      expect(rules.match(/@font-face/g)).toHaveLength(4)
      expect(rules).toContain(
        "font-family:'v2-p2';src:url('https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v2/woff2/p2.woff2')",
      )
      expect(rules).toContain('font-display:block')
      expect(screen.getByText('Page 2 of 604')).toBeDefined()
    })

    it('leaves out the surah-name and bismillah fonts when the page has no such line', () => {
      const lines = layoutPreview.page.lines.slice(2)
      render(
        <Preview preview={{ ...layoutPreview, page: { ...layoutPreview.page, lines } }} navigation={navigation()} />,
      )

      expect(css().match(/@font-face/g)).toHaveLength(1)
    })

    it('pages forward and back, jumps to a page, and to the page a surah starts on', () => {
      const nav = navigation()
      render(<Preview preview={layoutPreview} navigation={nav} />)

      fireEvent.click(screen.getByRole('button', { name: /Next page/ }))
      expect(nav.navigate).toHaveBeenLastCalledWith({ page: 3 })
      fireEvent.click(screen.getByRole('button', { name: /Previous page/ }))
      expect(nav.navigate).toHaveBeenLastCalledWith({ page: 1 })

      const jump = screen.getByRole('spinbutton', { name: 'Page' })
      expect(jump.getAttribute('max')).toBe('604')
      fireEvent.change(jump, { target: { value: '300' } })
      fireEvent.click(screen.getByRole('button', { name: 'Go' }))
      expect(nav.navigate).toHaveBeenLastCalledWith({ page: 300 })

      const surah = screen.getByRole('combobox', { name: 'Surah' }) as HTMLSelectElement
      expect(surah.value).toBe('2')
      fireEvent.change(surah, { target: { value: '3' } })
      expect(nav.navigate).toHaveBeenLastCalledWith({ page: 50 })
    })

    it('says so when the page font cannot be loaded', async () => {
      fontsLoad('failed')
      render(<Preview preview={layoutPreview} navigation={navigation()} />)

      expect(await screen.findByText(/The font v2-p2 could not be loaded/)).toBeDefined()
      expect(screen.getByTestId('mushaf-page').dataset.fontStatus).toBe('failed')
    })
  })

  describe('a font', () => {
    it('shows its sample in the font and lets the reader type their own text', async () => {
      render(<Preview preview={fontPreview} navigation={navigation()} />)

      const sample = screen.getByTestId('font-sample')
      expect(sample.style.fontFamily).toBe('"surah-name-v4-icon"')
      expect(sample.textContent).toBe('surah001')
      fireEvent.change(screen.getByRole('textbox', { name: 'Your text' }), { target: { value: 'surah002' } })
      expect(sample.textContent).toBe('surah002')
      await waitFor(() => expect(sample.dataset.fontStatus).toBe('loaded'))
    })

    it('switches to the ligatures and glyphs views through the URL', () => {
      const nav = navigation()
      render(<Preview preview={fontPreview} navigation={nav} />)

      const views = screen.getByRole('tablist', { name: 'Font views' })
      expect(
        within(views)
          .getAllByRole('tab')
          .map((tab) => tab.textContent),
      ).toEqual(['Sample', 'Ligatures', 'Glyphs'])
      fireEvent.mouseDown(within(views).getByRole('tab', { name: 'Glyphs' }))
      expect(nav.showView).toHaveBeenCalledWith('glyphs', { view: 'glyphs' })
    })

    it('lists every ligature, filtered by name', () => {
      render(<Preview preview={{ ...fontPreview, view: 'ligatures' }} navigation={navigation()} />)

      expect(screen.getByTestId('ligature-count').textContent).toBe('3 ligatures')
      fireEvent.change(screen.getByRole('searchbox', { name: 'Filter ligatures' }), { target: { value: 'icon' } })
      expect(screen.getByTestId('ligature-count').textContent).toBe('1 of 3 ligatures')
      expect(document.querySelector('[data-ligature="surah icon"]')?.textContent).toContain('surah-icon')
    })

    it('has no Ligatures view for a font without ligatures, and shows the mushaf page of a page font', () => {
      const { page } = layoutPreview
      render(<Preview preview={{ ...fontPreview, ligatures: [], sample: null, page }} navigation={navigation()} />)

      expect(screen.queryByRole('tab', { name: 'Ligatures' })).toBeNull()
      expect(screen.getByTestId('mushaf-preview').dataset.page).toBe('2')
    })
  })

  describe('a Quran script', () => {
    it('shows each word in the font of its page, and moves through surahs and ayah ranges', () => {
      const nav = navigation()
      render(<Preview preview={scriptPreview} navigation={nav} />)

      const words = document.querySelectorAll<HTMLElement>('[data-word] span')
      expect(Array.from(words).map((word) => word.style.fontFamily)).toEqual(['"v2-p604"', '"v2-p604"', '"v2-p604"'])
      expect(screen.getByText('Surah Al-Ikhlas, ayahs 1–2 of 4')).toBeDefined()

      fireEvent.click(screen.getByRole('button', { name: /Next ayahs/ }))
      expect(nav.navigate).toHaveBeenLastCalledWith({ surah: 112, from: 3 })
      expect((screen.getByRole('button', { name: /Previous ayahs/ }) as HTMLButtonElement).disabled).toBe(true)
      fireEvent.change(screen.getByRole('combobox', { name: 'Surah' }), { target: { value: '1' } })
      expect(nav.navigate).toHaveBeenLastCalledWith({ surah: '1' })
    })

    it('draws ayah text with tajweed rules, and word images', () => {
      const tajweed = {
        ...scriptPreview,
        granularity: 'ayah' as const,
        rendering: 'html' as const,
        ayahs: [
          { key: '1:1', number: 1, text: 'بِسۡمِ <rule class="ham_wasl">ٱ</rule>للَّهِ', font: 'qpc-hafs', words: [] },
        ],
      }
      const { unmount } = render(<Preview preview={tajweed} navigation={navigation()} />)
      expect(screen.getByTestId('script-text').className).toContain('tajweed')
      expect(document.querySelector('rule.ham_wasl')?.textContent).toBe('ٱ')
      unmount()

      const images = {
        ...scriptPreview,
        rendering: 'image' as const,
        fonts: [],
        ayahs: [
          {
            key: '1:1',
            number: 1,
            text: null,
            font: null,
            words: [{ id: 1, text: null, font: null, imageUrl: '/w/1.png' }],
          },
        ],
      }
      render(<Preview preview={images} navigation={navigation()} />)
      expect(document.querySelector('img')?.getAttribute('src')).toBe('/w/1.png')
      expect(screen.getByTestId('script-text').dataset.fontStatus).toBe('none')
    })
  })

  it('gives the reason when a resource cannot be previewed, and the general state when its type has no preview', () => {
    const { unmount } = render(
      <Preview
        preview={{ kind: 'unavailable', reason: 'This layout has no mushaf data yet.' }}
        navigation={navigation()}
      />,
    )
    expect(screen.getByTestId('no-preview').textContent).toContain('This layout has no mushaf data yet.')
    unmount()

    render(<Preview preview={null} navigation={navigation()} />)
    expect(screen.getByTestId('no-preview').textContent).toContain('No preview for this resource yet')
  })
})

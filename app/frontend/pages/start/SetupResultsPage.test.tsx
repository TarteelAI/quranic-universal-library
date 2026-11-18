import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { BUNDLE_KEY, resetBundle } from '@/lib/bundle'
import { renderPage } from '@/test/inertia'
import { setupResultsProps } from '@/test/start'

import SetupResultsPage from './SetupResultsPage'

describe('start/SetupResultsPage', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    window.localStorage.clear()
    resetBundle()
  })

  it('shows the banner, the needs checklist and a section of resources per need', () => {
    renderPage(SetupResultsPage, { props: setupResultsProps, url: '/resources?goal=reader' })

    expect(screen.getByText('Filtered for your Quran reader app')).toBeDefined()
    expect(screen.getByText(/iOS and Android/)).toBeDefined()
    expect(screen.getByRole('link', { name: 'Edit answers' }).getAttribute('href')).toBe(setupResultsProps.editPath)
    expect(screen.getByRole('link', { name: 'Show everything' }).getAttribute('href')).toBe('/resources')

    const checklist = within(screen.getByRole('navigation', { name: 'Your app needs' }))
    expect(checklist.getAllByRole('link').map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['Translation in English9', '#need-translation-en'],
      ['Tafsir in Urdu0', '#need-tafsir-ur'],
      ['Tajweed text0', '#need-tajweed'],
    ])

    const translations = within(screen.getByRole('region', { name: /Translation in English/ }))
    expect(translations.getByRole('link', { name: 'Sahih International' }).getAttribute('href')).toBe(
      '/resources/translation/sahih-international',
    )
    expect(translations.getByRole('link', { name: /See all 9/ }).getAttribute('href')).toBe(
      '/resources?granularity=1_ayah&language=en&type=translation',
    )
    const tafsir = within(screen.getByRole('region', { name: /Tafsir in Urdu/ }))
    expect(tafsir.getByText('Nothing in the library fits this yet.')).toBeDefined()
    expect(tafsir.queryByRole('link')).toBeNull()

    // A need narrowed to a script with nothing tagged says so, and never lists other scripts as matches.
    const tajweed = within(screen.getByRole('region', { name: /Tajweed text/ }))
    expect(tajweed.getByText(/No IndoPak resources of this kind are tagged yet\./)).toBeDefined()
    expect(tajweed.queryByRole('list')).toBeNull()
    expect(tajweed.getByRole('link', { name: 'Browse all Quran script resources' }).getAttribute('href')).toBe(
      '/resources/quran-script',
    )
  })

  it("points the bundle tray at the answers' file formats", async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1]))
    resetBundle()
    const file = (id: number, format: 'json' | 'sqlite', formatLabel: string) => ({
      id,
      name: `Saheeh ${formatLabel}`,
      format,
      formatLabel,
      byteSize: 2048,
      md5: 'abc',
    })
    const item = {
      id: 1,
      restricted: false,
      resource: { id: 1, name: 'Saheeh International', type: 'translation', toParam: 'saheeh' },
      category: 'translation' as const,
      files: [file(11, 'json', 'JSON'), file(12, 'sqlite', 'SQLite')],
    }
    vi.stubGlobal(
      'fetch',
      vi.fn(() => Promise.resolve(new Response(JSON.stringify({ items: [item], downloadMode: 'public' })))),
    )
    renderPage(SetupResultsPage, { props: setupResultsProps, url: '/resources?goal=reader' })

    fireEvent.click(screen.getByRole('button', { name: /^Bundle, / }))
    const tray = within(screen.getByRole('dialog', { name: 'Bundle' }))
    const files = await tray.findByRole('list', { name: 'Files of Saheeh International' })
    expect(
      within(files)
        .getAllByRole('link')
        .map((link) => link.textContent),
    ).toEqual([expect.stringContaining('Saheeh SQLite')])
    expect(tray.getByRole('button', { name: 'Show all files' })).toBeTruthy()
  })
})

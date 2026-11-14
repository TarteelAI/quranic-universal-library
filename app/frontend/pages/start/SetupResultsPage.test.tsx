import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { renderPage } from '@/test/inertia'
import { setupResultsProps } from '@/test/start'

import SetupResultsPage from './SetupResultsPage'

describe('start/SetupResultsPage', () => {
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
  })
})

import { fireEvent, render, screen, within } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { recordsPreview, translationPreview, wordTranslationPreview } from '@/test/previews'

import type { PreviewNavigation } from './navigation'
import { Preview } from './preview'

function navigation(): PreviewNavigation {
  return { navigate: vi.fn(), showView: vi.fn(), loading: false }
}

describe('a text preview', () => {
  it('shows each ayah in Arabic and the text in its language and direction, with its footnotes', () => {
    render(<Preview preview={translationPreview} navigation={navigation()} />)

    const entry = screen.getByTestId('text-preview').querySelector<HTMLElement>('[data-entry="2:1"]')!
    expect(within(entry).getByText('الٓمٓ').getAttribute('dir')).toBe('rtl')
    const text = entry.querySelector('[lang="ur"]')!
    expect(text.getAttribute('dir')).toBe('rtl')
    expect(text.innerHTML).toBe('الم<sup>1</sup>')
    const footnotes = within(entry).getByRole('list', { name: 'Footnotes' })
    expect(footnotes.innerHTML).toContain('<b>مقطعات</b>')
    expect(screen.getByText('No text for this ayah in this resource.')).toBeDefined()
  })

  it('shows a word-by-word resource word by word', () => {
    render(<Preview preview={wordTranslationPreview} navigation={navigation()} />)

    expect(screen.getByText('بِسْمِ')).toBeDefined()
    expect(screen.getByText('(of) Allah').getAttribute('dir')).toBe('ltr')
  })

  it('pages through the surah by ayah range', () => {
    const nav = navigation()
    render(<Preview preview={translationPreview} navigation={nav} />)

    fireEvent.click(screen.getByRole('button', { name: /Next ayahs/ }))
    expect(nav.navigate).toHaveBeenCalledWith({ surah: 2, from: 3 })
    fireEvent.change(screen.getByRole('combobox', { name: 'Surah' }), { target: { value: '114' } })
    expect(nav.navigate).toHaveBeenCalledWith({ surah: 114 })
  })

  it('says when a long entry was cut', () => {
    const [entry] = translationPreview.entries
    render(
      <Preview
        preview={{ ...translationPreview, entries: [{ ...entry, truncated: true }] }}
        navigation={navigation()}
      />,
    )

    expect(screen.getByText(/the preview shows its start/)).toBeDefined()
  })
})

describe('a records preview', () => {
  it('shows the records with their tags, and the bound', () => {
    render(<Preview preview={recordsPreview} navigation={navigation()} />)

    expect(screen.getByText('1:1–1:7')).toBeDefined()
    expect(screen.getByText('Supplic')).toBeDefined()
    expect(screen.getByText(/at most 10/)).toBeDefined()
  })

  it('has no surah picker when the records do not go by surah, and says when there are none', () => {
    render(<Preview preview={{ ...recordsPreview, surah: null, records: [] }} navigation={navigation()} />)

    expect(screen.queryByRole('combobox', { name: 'Surah' })).toBeNull()
    expect(screen.getByText('No records in this resource.')).toBeDefined()
  })

  it('moves to the next surah', () => {
    const nav = navigation()
    render(<Preview preview={recordsPreview} navigation={nav} />)

    fireEvent.click(screen.getByRole('button', { name: /Next surah/ }))
    expect(nav.navigate).toHaveBeenCalledWith({ surah: 2 })
  })
})

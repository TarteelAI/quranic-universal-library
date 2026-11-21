import { describe, expect, it } from 'vitest'

import type { ContentDocsSearchEntry } from '@/types/serializers'

import { fold, searchDocs } from './docs-search'

const page = (key: string, title: string, headings: string[], text: string): ContentDocsSearchEntry => ({
  key,
  title,
  category: 'Guides',
  headings: headings.map((heading, index) => ({ id: `h${index}`, text: heading, level: 2 })),
  text,
})

const PAGES = [
  page('setup', 'Project setup', ['Install the CLI', 'Morphology layers'], 'Start here with any package.'),
  page('tajweed', 'Tajweed guide', ['Colour rules'], 'Rules for the الْقُرْآن text, and the Qurʾān script.'),
  page('morphology', 'Morphology guide', ['Roots'], 'Lemmas and stems.'),
]

describe('fold', () => {
  it('folds case, accents, Arabic vowel marks, hamza seats and tatweel', () => {
    expect(fold('Qurʾān')).toBe('quran')
    expect(fold('الْقُرْآن')).toBe('القران')
    expect(fold('إسلام')).toBe('اسلام')
    expect(fold('ٱلرَّحْمَـٰن')).toBe('الرحمن')
    expect(fold('سورة')).toBe('سوره')
  })
})

describe('searchDocs', () => {
  it('ranks title hits first, then heading hits at their heading, then text hits', () => {
    expect(searchDocs(PAGES, 'morphology', 10)).toEqual([
      { key: 'morphology', title: 'Morphology guide', detail: 'Guides', href: '/docs/morphology' },
      { key: 'setup#h1', title: 'Morphology layers', detail: 'Project setup', href: '/docs/setup#h1' },
    ])
    expect(searchDocs(PAGES, 'package', 10).map((hit) => hit.key)).toEqual(['setup'])
  })

  it('needs every word, in any field, and finds Arabic and transliterated terms without their marks', () => {
    expect(searchDocs(PAGES, 'install cli', 10).map((hit) => hit.key)).toEqual(['setup#h0'])
    expect(searchDocs(PAGES, 'install roots', 10)).toEqual([])
    expect(searchDocs(PAGES, 'القرآن', 10).map((hit) => hit.key)).toEqual(['tajweed'])
    expect(searchDocs(PAGES, 'QURAN', 10).map((hit) => hit.key)).toEqual(['tajweed'])
  })

  it('finds nothing for an empty query, and keeps to the limit', () => {
    expect(searchDocs(PAGES, '  ', 10)).toEqual([])
    expect(searchDocs(PAGES, 'e', 2)).toHaveLength(2)
  })
})

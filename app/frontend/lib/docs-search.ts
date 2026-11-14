import * as React from 'react'

import { docsPage, docsSearchIndex } from '@/routes'
import type { ContentDocsSearchEntry } from '@/types/serializers'

/** A docs page that matches a query, at the heading that matches when one does. */
export type DocsHit = { key: string; title: string; detail: string | null; href: string }

// The index is asked for once per page load, on first use, and kept for every later search. A
// failed request is not kept, so the next use asks again.
let request: Promise<ContentDocsSearchEntry[] | null> | null = null
let loaded: ContentDocsSearchEntry[] | null = null

function loadDocsIndex() {
  request ??= fetch(docsSearchIndex().url, { headers: { Accept: 'application/json' } })
    .then((response) => (response.ok ? (response.json() as Promise<{ pages: ContentDocsSearchEntry[] }>) : null))
    .catch(() => null)
    .then((found) => {
      loaded = found?.pages ?? null
      if (!loaded) request = null
      return loaded
    })
  return request
}

/** The docs index once `wanted` has been true on this page load, else null. */
export function useDocsIndex(wanted: boolean) {
  const [pages, setPages] = React.useState(loaded)
  React.useEffect(() => {
    if (!wanted || pages) return
    let mounted = true
    void loadDocsIndex().then((found) => {
      if (mounted && found) setPages(found)
    })
    return () => {
      mounted = false
    }
  }, [wanted, pages])
  return pages
}

/** Forgets the index, as a new page load would. For tests. */
export function forgetDocsIndex() {
  request = null
  loaded = null
}

/**
 * Text as it is matched: lower case, without accents and Arabic vowel marks (combining marks once
 * decomposed, so "Qurʾān" is "quran"), the hamza seats and alef wasla folded into a bare alef,
 * alef maqsura into ya, ta marbuta into ha, and no tatweel.
 */
export function fold(text: string) {
  return text
    .normalize('NFKD')
    .replace(/[\p{M}ʾʿـ]/gu, '')
    .replace(/[ٱأإآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .toLowerCase()
}

type Folded = { page: ContentDocsSearchEntry; title: string; headings: string[]; all: string }

const folded = new WeakMap<ContentDocsSearchEntry[], Folded[]>()

function foldIndex(pages: ContentDocsSearchEntry[]) {
  let entries = folded.get(pages)
  if (!entries) {
    entries = pages.map((page) => {
      const headings = page.headings.map((heading) => fold(heading.text))
      const title = fold(page.title)
      return { page, title, headings, all: [title, ...headings, fold(page.text)].join(' ') }
    })
    folded.set(pages, entries)
  }
  return entries
}

/**
 * The pages where every word of the query appears, in its title, headings or text. Pages whose
 * title holds every word come first, then those with a heading that does (the hit opens the page
 * at that heading), then the rest; within each, in reading order.
 */
export function searchDocs(pages: ContentDocsSearchEntry[], query: string, limit: number): DocsHit[] {
  const words = fold(query).split(/\s+/).filter(Boolean)
  if (words.length === 0) return []
  const hasAll = (text: string) => words.every((word) => text.includes(word))

  const ranked: { hit: DocsHit; rank: number }[] = []
  for (const entry of foldIndex(pages)) {
    if (!hasAll(entry.all)) continue
    const { page } = entry
    const href = docsPage(page.key).url
    const inTitle = hasAll(entry.title)
    const heading = inTitle ? -1 : entry.headings.findIndex(hasAll)
    if (heading >= 0) {
      const { id, text } = page.headings[heading]
      ranked.push({
        hit: { key: `${page.key}#${id}`, title: text, detail: page.title, href: `${href}#${id}` },
        rank: 1,
      })
    } else {
      ranked.push({ hit: { key: page.key, title: page.title, detail: page.category, href }, rank: inTitle ? 0 : 2 })
    }
  }
  return ranked
    .sort((a, b) => a.rank - b.rank)
    .slice(0, limit)
    .map(({ hit }) => hit)
}

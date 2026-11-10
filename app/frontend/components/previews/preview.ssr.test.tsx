// @vitest-environment node
import { describe, expect, it } from 'vitest'

import ResourcePage from '@/pages/catalog/ResourcePage'
import { resourcePageProps } from '@/test/catalog'
import { renderPageOnServer } from '@/test/inertia'
import {
  fontPreview,
  layoutPreview,
  recitationPreview,
  recordsPreview,
  scriptPreview,
  translationPreview,
} from '@/test/previews'

describe('previews on the server', () => {
  it.each([
    ['a mushaf page', layoutPreview, "font-family:'v2-p2'"],
    ['a font', fontPreview, 'surah001'],
    ['a Quran script', scriptPreview, '112:1'],
  ])('renders %s with its font rules and without browser globals', async (_name, preview, text) => {
    const { body } = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, preview },
      url: '/resources/tafsir/tafsir-ibn-kathir',
    })

    expect(body).toContain(text)
    expect(body).toContain('@font-face')
  })
})

describe('audio, text and record previews on the server', () => {
  it.each([
    ['a recitation', recitationPreview, 'data-testid="recitation-preview"'],
    ['a translation', translationPreview, 'lang="ur" dir="rtl"'],
    ['a sample of records', recordsPreview, 'Supplication to Allah'],
  ])('renders %s without browser globals', async (_name, preview, text) => {
    const { body } = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, preview },
      url: '/resources/tafsir/tafsir-ibn-kathir',
    })

    expect(body).toContain(text)
  })

  it('renders no audio source before the listener presses play', async () => {
    const { body } = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, preview: recitationPreview },
      url: '/resources/recitation/husary',
    })

    expect(body).toMatch(/<audio preload="none"><\/audio>/)
  })
})

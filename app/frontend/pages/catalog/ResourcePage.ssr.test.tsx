// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { resourcePageProps } from '@/test/catalog'
import { renderPageOnServer } from '@/test/inertia'

import ResourcePage from './ResourcePage'

describe('catalog/ResourcePage on the server', () => {
  it('renders the header, the files and the open tab without browser globals', async () => {
    const { body } = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, tab: 'changelog' },
      url: '/resources/tafsir/tafsir-ibn-kathir?tab=changelog',
    })

    expect(body).toContain('Tafsir Ibn Kathir')
    expect(body).toContain('5.1 MB')
    expect(body).toContain('Fixed footnotes')
  })

  it('renders the Data and Docs tabs from the format doc', async () => {
    const data = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, tab: 'data' },
      url: '/resources/tafsir/tafsir-ibn-kathir?tab=data',
    })
    expect(data.body).toContain('the ayah this row is for.')
    // The download URL has no origin on the server; the browser adds it after hydration.
    expect(data.body).toContain('>/resources/tafsir/tafsir-ibn-kathir/download/11<')

    const docs = await renderPageOnServer(ResourcePage, {
      props: { ...resourcePageProps, tab: 'docs' },
      url: '/resources/tafsir/tafsir-ibn-kathir?tab=docs',
    })
    expect(docs.body).toContain('About tafsir data')
  })
})

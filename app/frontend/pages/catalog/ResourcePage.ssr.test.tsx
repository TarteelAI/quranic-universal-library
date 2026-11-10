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
})

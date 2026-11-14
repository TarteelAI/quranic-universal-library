// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { docsIndexProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import DocsIndexPage from './DocsIndexPage'

describe('content/DocsIndexPage on the server', () => {
  it('renders the categories and the side navigation without browser globals', async () => {
    const { body } = await renderPageOnServer(DocsIndexPage, { props: docsIndexProps, url: '/docs' })

    expect(body).toContain('QUL documentation')
    expect(body).toContain('href="/docs/download-resources"')
    expect(body).toMatch(/<a[^>]*aria-current="page"[^>]*href="\/docs"/)
  })
})

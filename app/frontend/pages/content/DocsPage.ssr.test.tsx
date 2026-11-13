// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { docsPageProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import DocsPage from './DocsPage'

describe('content/DocsPage on the server', () => {
  it('renders the body, a code block, the example frame and the side navigation without browser globals', async () => {
    const { body } = await renderPageOnServer(DocsPage, {
      props: docsPageProps,
      url: '/docs/tutorial-recitation-end-to-end',
    })

    expect(body).toContain('<h2 id="what-you-will-build">What you will build</h2>')
    expect(body).toContain('{ &quot;1:1&quot;: { &quot;segments&quot;: [] } }')
    expect(body).toMatch(/<iframe[^>]*sandbox="allow-scripts"[^>]*srcDoc="[^"]*Word 1:1:1/)
    expect(body).toMatch(/<a[^>]*aria-current="page"[^>]*href="\/docs\/tutorial-recitation-end-to-end"/)
  })
})

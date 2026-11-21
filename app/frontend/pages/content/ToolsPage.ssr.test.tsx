// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { toolsProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import ToolsPage from './ToolsPage'

describe('content/ToolsPage on the server', () => {
  it('renders the tool groups without browser globals', async () => {
    const { body } = await renderPageOnServer(ToolsPage, { props: toolsProps, url: '/tools' })

    expect(body).toContain('Mushaf &amp; scripts')
    expect(body).toContain('href="/mushaf_layouts"')
  })
})

// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { changelogEntryProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import ChangelogEntryPage from './ChangelogEntryPage'

describe('content/ChangelogEntryPage on the server', () => {
  it('renders the entry without browser globals', async () => {
    const { body } = await renderPageOnServer(ChangelogEntryPage, { props: changelogEntryProps, url: '/changelog/31' })

    expect(body).toContain('<strong>6,218</strong>')
    expect(body).toContain('href="/resources/translation/diyanet-isleri"')
  })
})

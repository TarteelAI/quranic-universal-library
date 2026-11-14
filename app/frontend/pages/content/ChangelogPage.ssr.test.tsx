// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { changelogProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import ChangelogPage from './ChangelogPage'

describe('content/ChangelogPage on the server', () => {
  it('renders the entries and the pager without browser globals', async () => {
    const { body } = await renderPageOnServer(ChangelogPage, { props: changelogProps, url: '/changelog?page=2' })

    expect(body).toContain('href="/changelog/31"')
    expect(body).toContain('href="/changelog?page=3"')
  })
})

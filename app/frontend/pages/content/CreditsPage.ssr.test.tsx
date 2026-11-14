// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { creditsProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import CreditsPage from './CreditsPage'

describe('content/CreditsPage on the server', () => {
  it('renders the credits without browser globals', async () => {
    const { body } = await renderPageOnServer(CreditsPage, { props: creditsProps, url: '/credits' })

    expect(body).toContain('Tafsir Center')
    expect(body).toContain('href="https://recitequran.com"')
    expect(body).toContain('octocat')
  })
})

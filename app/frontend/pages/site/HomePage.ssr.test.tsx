// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { homePageProps } from '@/test/site'

import HomePage from './HomePage'

describe('site/HomePage on the server', () => {
  it('renders the hero, the counts and the showcase without browser globals', async () => {
    const { body } = await renderPageOnServer(HomePage, { props: homePageProps })

    expect(body).toContain('Verified data for builders impacting the Ummah.')
    expect(body).toContain('<canvas')
    expect(body).toContain('547')
    expect(body).toContain('QuranWBW')
    // The star count is fetched in the browser; the server renders the fallback.
    expect(body).toContain('1.1k')
  })
})

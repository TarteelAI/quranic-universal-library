// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { appsPageProps } from '@/test/site'

import AppsPage from './AppsPage'

describe('site/AppsPage on the server', () => {
  it('renders the directory and its filters without browser globals', async () => {
    const { body } = await renderPageOnServer(AppsPage, {
      props: { ...appsPageProps, filters: { platform: 'android', type: null } },
      url: '/apps?platform=android',
    })

    expect(body).toContain('Apps built with QUL')
    expect(body).toContain('QuranWBW')
    expect(body).toMatch(/aria-pressed="true"[^>]*>.*Android/)
  })
})

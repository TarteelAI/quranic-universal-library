// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { kitPageProps } from '@/test/start'

import KitPage from './KitPage'

describe('start/KitPage on the server', () => {
  it('renders the kit without browser globals', async () => {
    const { body } = await renderPageOnServer(KitPage, { props: kitPageProps, url: '/kits/madani-reader' })

    expect(body).toContain('Madani reader')
    expect(body).toContain('The Clear Quran')
  })
})

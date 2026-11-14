// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { kitsPageProps } from '@/test/start'

import KitsPage from './KitsPage'

describe('start/KitsPage on the server', () => {
  it('renders the kits without browser globals', async () => {
    const { body } = await renderPageOnServer(KitsPage, { props: kitsPageProps, url: '/kits' })

    expect(body).toContain('Starter kits')
    expect(body).toContain('Recitation with highlighting')
  })
})

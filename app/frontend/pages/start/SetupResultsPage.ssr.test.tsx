// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { setupResultsProps } from '@/test/start'

import SetupResultsPage from './SetupResultsPage'

describe('start/SetupResultsPage on the server', () => {
  it('renders the results without browser globals', async () => {
    const { body } = await renderPageOnServer(SetupResultsPage, {
      props: setupResultsProps,
      url: '/resources?goal=reader',
    })

    expect(body).toContain('Your app needs')
    expect(body).toContain('Sahih International')
  })
})

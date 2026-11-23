// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { setupPageProps } from '@/test/start'

import SetupPage from './SetupPage'

describe('start/SetupPage on the server', () => {
  it('renders the step the answers open at without browser globals', async () => {
    const answers = { ...setupPageProps.answers, goals: ['reader'], answered: ['goal' as const], step: 1 }
    const { body } = await renderPageOnServer(SetupPage, {
      props: { ...setupPageProps, answers },
      url: '/start?goal=reader',
    })

    expect(body).toContain('Where will it run?')
    expect(body).toContain('Step 2 of 5')
  })
})

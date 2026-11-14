// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'

import ErrorPage from './ErrorPage'

describe('errors/ErrorPage on the server', () => {
  it('renders the not-found message without browser globals', async () => {
    const { body } = await renderPageOnServer(ErrorPage, { props: { status: 404 } })

    expect(body).toContain('Page not found')
    expect(body).toContain('Error 404')
  })
})

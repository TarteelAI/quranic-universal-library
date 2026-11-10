// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'

import InertiaSample from './InertiaSample'

describe('dev/InertiaSample on the server', () => {
  it('renders without browser globals', async () => {
    const { body } = await renderPageOnServer(InertiaSample, { props: { heading: 'Sample heading' } })

    expect(body).toContain('Sample heading')
    expect(body).toContain('Loading the resource count.')
  })
})

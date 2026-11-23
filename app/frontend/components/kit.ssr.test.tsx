// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { componentNames, fixtures } from '@/test/kit'

describe('the UI kit on the server', () => {
  it('has a render fixture for every exported component', () => {
    expect(Object.keys(fixtures).sort()).toEqual(componentNames)
  })

  it.each(componentNames)('%s renders without browser globals', async (name) => {
    const { element, text } = fixtures[name]
    const { body } = await renderPageOnServer(() => element, {
      props: {},
      url: '/resources',
      flash: { notice: 'Signed in successfully.' },
    })

    expect(body).toContain(text)
  })
})

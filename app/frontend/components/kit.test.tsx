import { afterEach, describe, expect, it } from 'vitest'

import { hydratePage } from '@/test/inertia'
import { componentNames, fixtures } from '@/test/kit'

describe('the UI kit in the browser', () => {
  let unmount: (() => void) | undefined
  afterEach(() => {
    unmount?.()
    document.body.innerHTML = ''
  })

  it.each(componentNames)('%s hydrates the server HTML without a mismatch', async (name) => {
    const { element, text, openText } = fixtures[name]
    const hydrated = await hydratePage(() => element, {
      props: {},
      url: '/resources',
      flash: { notice: 'Signed in successfully.' },
    })
    unmount = hydrated.unmount

    expect(hydrated.logged).toEqual([])
    expect(hydrated.container.innerHTML).toContain(text)
    if (openText) expect(document.body.textContent).toContain(openText)
  })
})

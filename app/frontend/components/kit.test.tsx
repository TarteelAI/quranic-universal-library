import { afterEach, describe, expect, it } from 'vitest'

import { BUNDLE_KEY, resetBundle } from '@/lib/bundle'
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

  // The server renders an empty bundle; the browser's stored one shows right after hydration.
  it('hydrates the header and a card without a mismatch when the browser holds a bundle', async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1, 2]))
    resetBundle()
    const hydrated = await hydratePage(
      () => (
        <>
          {fixtures.SiteHeader.element}
          {fixtures.ResourceCard.element}
        </>
      ),
      { props: {}, url: '/resources' },
    )
    unmount = hydrated.unmount
    window.localStorage.clear()
    resetBundle()

    expect(hydrated.logged).toEqual([])
    expect(hydrated.container.querySelector('[data-testid="bundle-count"]')?.textContent).toBe('2')
    expect(hydrated.container.querySelector('[aria-label="Remove Sahih International from bundle"]')).not.toBeNull()
  })
})

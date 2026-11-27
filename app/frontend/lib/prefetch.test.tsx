import { router } from '@inertiajs/react'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { NavAnchor } from '@/components/qul/nav'

import { flushPrefetchedOnWrite, onVisitStart, PREFETCH_CACHE_FOR, prefetchable } from './prefetch'

describe('prefetchable', () => {
  it('takes every new page but the catalog and the signed-in user’s own pages', () => {
    expect(prefetchable('/resources/translation')).toBe(true)
    expect(prefetchable('/resources/translation/sahih-international')).toBe(true)
    expect(prefetchable('/docs/api')).toBe(true)
    expect(prefetchable('/requests?request=new')).toBe(true)
    expect(prefetchable('/resources')).toBe(false)
    expect(prefetchable('/resources?category=translations')).toBe(false)
    expect(prefetchable('/profile')).toBe(false)
    expect(prefetchable('/profile/edit')).toBe(false)
    expect(prefetchable('/profile?tab=downloads')).toBe(false)
  })
})

describe('NavAnchor prefetch', () => {
  let prefetch: ReturnType<typeof vi.spyOn>
  beforeEach(() => {
    vi.useFakeTimers()
    prefetch = vi.spyOn(router, 'prefetch').mockImplementation(() => {})
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  const link = (href: string, inertia = true) => {
    render(<NavAnchor link={{ href, inertia }}>Go</NavAnchor>)
    return screen.getByRole('link', { name: 'Go' })
  }
  const rest = (ms: number) => act(() => vi.advanceTimersByTime(ms))

  it('fetches a new page after the pointer rests on its link for Inertia’s delay, with the kept-for time', () => {
    fireEvent.mouseEnter(link('/resources/mushaf-layout'))
    rest(74)
    expect(prefetch).not.toHaveBeenCalled()
    rest(1)
    expect(prefetch).toHaveBeenCalledOnce()
    expect(prefetch.mock.calls[0][0]).toBe('/resources/mushaf-layout')
    expect(prefetch.mock.calls[0][2]).toMatchObject({ cacheFor: PREFETCH_CACHE_FOR })
  })

  it('fetches nothing when the pointer passes over the link', () => {
    const anchor = link('/resources/mushaf-layout')
    fireEvent.mouseEnter(anchor)
    rest(40)
    fireEvent.mouseLeave(anchor)
    rest(200)
    expect(prefetch).not.toHaveBeenCalled()
  })

  it('fetches ahead on keyboard focus too', () => {
    const anchor = link('/docs/api')
    const matches = vi.spyOn(anchor, 'matches').mockReturnValue(true)
    act(() => anchor.focus())
    rest(75)
    expect(matches).toHaveBeenCalledWith(':focus-visible')
    expect(prefetch).toHaveBeenCalledWith('/docs/api', {}, { cacheFor: PREFETCH_CACHE_FOR })
  })

  it('does not fetch ahead on a focus that is not the keyboard’s, or once the link is left', () => {
    const anchor = link('/docs/api')
    const matches = vi.spyOn(anchor, 'matches').mockReturnValue(false)
    act(() => anchor.focus())
    rest(200)
    matches.mockReturnValue(true)
    act(() => anchor.blur())
    act(() => anchor.focus())
    rest(40)
    act(() => anchor.blur())
    rest(200)
    expect(prefetch).not.toHaveBeenCalled()
  })

  it('never fetches the catalog, the user’s own pages or an old page', () => {
    for (const [href, inertia] of [
      ['/resources', true],
      ['/profile', true],
      ['/tajweed_words', false],
    ] as const) {
      fireEvent.mouseEnter(link(href, inertia))
      rest(200)
      cleanup()
    }
    expect(prefetch).not.toHaveBeenCalled()
  })
})

describe('flushPrefetchedOnWrite', () => {
  afterEach(() => vi.restoreAllMocks())

  it('drops every kept page after a visit that writes, and none after a GET', () => {
    const flushAll = vi.spyOn(router, 'flushAll')
    const stop = flushPrefetchedOnWrite()
    const finish = (method: string) =>
      document.dispatchEvent(new CustomEvent('inertia:finish', { detail: { visit: { method } } }))

    finish('get')
    expect(flushAll).not.toHaveBeenCalled()
    finish('post')
    finish('delete')
    expect(flushAll).toHaveBeenCalledTimes(2)
    stop()
  })
})

describe('onVisitStart', () => {
  it('calls back when a visit starts, not when a prefetch does', () => {
    const callback = vi.fn()
    const stop = onVisitStart(callback)
    const start = (prefetch: boolean) =>
      document.dispatchEvent(new CustomEvent('inertia:start', { detail: { visit: { prefetch } } }))

    start(true)
    expect(callback).not.toHaveBeenCalled()
    start(false)
    expect(callback).toHaveBeenCalledOnce()
    stop()
  })
})

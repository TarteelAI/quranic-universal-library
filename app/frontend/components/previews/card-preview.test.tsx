import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { ResourceCard } from '@/components/qul/resource-card'
import { cardLayoutPreview, cardRecitationPreview, cardScriptPreview, cardTextPreview } from '@/test/previews'

import { CardPreview, type CardPreviewKind } from './card-preview'

// An IntersectionObserver the test moves on screen.
let observers: { callback: IntersectionObserverCallback; elements: Element[] }[] = []
class TestObserver {
  constructor(callback: IntersectionObserverCallback) {
    observers.push({ callback, elements: this.elements })
  }
  elements: Element[] = []
  observe(element: Element) {
    this.elements.push(element)
  }
  disconnect() {}
}

function scrollOnScreen() {
  act(() => {
    for (const { callback, elements } of observers) {
      callback(
        elements.map((target) => ({ target, isIntersecting: true }) as IntersectionObserverEntry),
        {} as IntersectionObserver,
      )
    }
  })
}

function respond(body: unknown, status = 200) {
  const fetch = vi.fn(() => Promise.resolve(new Response(JSON.stringify(body), { status })))
  vi.stubGlobal('fetch', fetch)
  return fetch
}

function css() {
  return Array.from(document.querySelectorAll('style'))
    .map((style) => style.innerHTML)
    .join('\n')
}

function card(kind: CardPreviewKind) {
  return (
    <ResourceCard
      title="Sahih International"
      href="/resources/translation/sahih-international"
      preview={<CardPreview kind={kind} url="/resources/translation/sahih-international/preview" />}
    />
  )
}

describe('CardPreview', () => {
  beforeEach(() => {
    observers = []
    vi.stubGlobal('IntersectionObserver', TestObserver)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('requests nothing and adds no font rule until the card is on screen', async () => {
    const fetch = respond(cardLayoutPreview)
    render(card('layout'))

    expect(screen.getByTestId('card-preview').dataset.state).toBe('waiting')
    expect(fetch).not.toHaveBeenCalled()
    expect(css()).not.toContain('@font-face')

    scrollOnScreen()
    await waitFor(() => expect(screen.getByTestId('card-preview').dataset.state).toBe('loaded'))
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(fetch).toHaveBeenCalledWith('/resources/translation/sahih-international/preview', expect.anything())
    expect(css()).toContain("font-family:'v2-p2'")
  })

  it('draws a layout thumbnail in the page font', async () => {
    respond(cardLayoutPreview)
    render(card('layout'))
    scrollOnScreen()

    const well = await screen.findByTestId('card-preview')
    await waitFor(() => expect(well.querySelectorAll('[data-line]')).toHaveLength(3))
    expect(well.querySelector<HTMLElement>('[dir="rtl"]')?.style.fontFamily).toBe('"v2-p2"')
  })

  it('plays a recitation only when asked, and loads no audio before that', async () => {
    respond(cardRecitationPreview)
    const play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue()
    render(card('recitation'))
    scrollOnScreen()

    const button = await screen.findByRole('button', { name: 'Play Surah Al-Fatihah' })
    const audio = document.querySelector('audio')!
    expect(audio.getAttribute('src')).toBeNull()
    expect(audio.getAttribute('preload')).toBe('none')

    fireEvent.click(button)
    expect(audio.getAttribute('src')).toBe(cardRecitationPreview.track)
    expect(play).toHaveBeenCalledTimes(1)
  })

  it('shows a script ayah in its fonts, and a translation in its language and direction', async () => {
    respond(cardScriptPreview)
    const { unmount } = render(card('script'))
    scrollOnScreen()
    await waitFor(() => expect(document.querySelectorAll('[style*="v2-p604"]')).toHaveLength(2))
    expect(css()).toContain("font-family:'v2-p604'")
    unmount()

    respond(cardTextPreview)
    render(card('text'))
    scrollOnScreen()
    const text = await screen.findByText('الم')
    expect(text.closest('[lang="ur"]')?.getAttribute('dir')).toBe('rtl')
  })

  it('leaves the card without a preview when the preview cannot be loaded', async () => {
    respond({}, 404)
    render(card('text'))
    scrollOnScreen()

    await waitFor(() => expect(screen.queryByTestId('card-preview')).toBeNull())
    expect(screen.getByRole('link', { name: 'Sahih International' })).toBeDefined()
  })

  it('leaves the card without a preview when the answer is another kind', async () => {
    respond({ kind: 'unavailable', reason: 'No font' })
    render(card('layout'))
    scrollOnScreen()

    await waitFor(() => expect(screen.queryByTestId('card-preview')).toBeNull())
    expect(screen.getByRole('link', { name: 'Sahih International' })).toBeDefined()
  })
})

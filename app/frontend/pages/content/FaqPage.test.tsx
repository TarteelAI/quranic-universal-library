import { screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { faqProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import FaqPage from './FaqPage'

describe('content/FaqPage', () => {
  afterEach(() => window.history.replaceState(null, '', '/'))

  it('lists each question, closed, with its answer as formatted text', () => {
    const { container } = renderPage(FaqPage, { props: faqProps, url: '/faq' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Frequently asked questions')
    const items = container.querySelectorAll('details')
    expect([...items].map((item) => [item.id, item.open])).toEqual([
      ['faq-1', false],
      ['faq-7', false],
    ])
    expect(items[0].querySelector('summary')?.textContent).toBe('What is QUL?')
    expect(items[0].querySelector('strong')?.textContent).toBe('Quran resources')
    expect(items[1].querySelector('a[href="/credits"]')).not.toBeNull()
  })

  it('opens the question the URL hash names', () => {
    Element.prototype.scrollIntoView = vi.fn()
    window.history.replaceState(null, '', '/faq#faq-7')
    const { container } = renderPage(FaqPage, { props: faqProps, url: '/faq' })

    expect(container.querySelector<HTMLDetailsElement>('#faq-7')?.open).toBe(true)
    expect(container.querySelector<HTMLDetailsElement>('#faq-1')?.open).toBe(false)
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledOnce()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(FaqPage, { props: faqProps })

    expect(logged).toEqual([])
    unmount()
  })
})

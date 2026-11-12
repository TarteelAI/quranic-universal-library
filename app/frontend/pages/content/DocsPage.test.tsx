import { act, fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { docsPageProps, tagDoc } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import DocsPage from './DocsPage'

describe('content/DocsPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('renders the body, the contents list and the neighbouring pages', () => {
    renderPage(DocsPage, { props: docsPageProps, url: '/docs/tutorial-recitation-end-to-end' })

    const article = screen.getByRole('article')
    expect(within(article).getByRole('heading', { level: 1 }).textContent).toBe('Tutorial 1: Recitation End-to-End')
    expect(within(article).getByRole('link', { name: 'highlights' }).getAttribute('href')).toBe('/docs/datasets')
    const contents = within(screen.getByRole('navigation', { name: 'On this page' }))
    expect(contents.getAllByRole('link').map((link) => link.getAttribute('href'))).toEqual([
      '#what-you-will-build',
      '#run-the-example',
    ])
    const pages = within(screen.getByRole('navigation', { name: 'Previous and next pages' }))
    expect(pages.getAllByRole('link').map((link) => link.getAttribute('href'))).toEqual([
      '/docs/tutorials',
      '/docs/tutorial-mushaf-layout-end-to-end',
    ])
    const breadcrumb = within(screen.getByRole('navigation', { name: 'Breadcrumb' }))
    expect(breadcrumb.getByRole('link', { name: 'Download Resources' }).getAttribute('href')).toBe(
      '/docs/download-resources',
    )
  })

  it('copies a code block', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined)
    vi.stubGlobal('navigator', { ...navigator, clipboard: { writeText } })
    renderPage(DocsPage, { props: docsPageProps })

    const block = screen.getByText('JSON').closest('figure')!
    await act(async () => fireEvent.click(within(block).getByRole('button', { name: 'Copy code' })))

    expect(writeText).toHaveBeenCalledWith('{ "1:1": { "segments": [] } }')
    expect(within(block).getByRole('button', { name: 'Copied' })).toBeDefined()
    vi.unstubAllGlobals()
  })

  it('runs the example in a sandboxed frame, and again with the edited code', () => {
    renderPage(DocsPage, { props: docsPageProps })

    const frame = () => screen.getByTitle('Example output') as HTMLIFrameElement
    expect(frame().getAttribute('sandbox')).toBe('allow-scripts')
    expect(frame().srcdoc).toContain('document.getElementById("app").textContent = "Word 1:1:1"')

    fireEvent.change(screen.getByLabelText('Example code'), { target: { value: 'console.log("edited")' } })
    const before = frame()
    fireEvent.click(screen.getByRole('button', { name: 'Run' }))
    expect(frame()).not.toBe(before)
    expect(frame().srcdoc).toContain('console.log("edited")')

    fireEvent.click(screen.getByRole('button', { name: 'Reset' }))
    expect((screen.getByLabelText('Example code') as HTMLTextAreaElement).value).toBe(
      'document.getElementById("app").textContent = "Word 1:1:1"',
    )
    expect(frame().srcdoc).toContain('Word 1:1:1')
  })

  it('titles a tag page above its body, with no previous or next pages', () => {
    renderPage(DocsPage, { props: { doc: tagDoc }, url: '/docs/murattal' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Murattal')
    expect(screen.queryByRole('navigation', { name: 'Previous and next pages' })).toBeNull()
    expect(within(screen.getByRole('navigation', { name: 'Breadcrumb' })).getAllByRole('link')).toHaveLength(1)
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(DocsPage, { props: docsPageProps })

    expect(logged).toEqual([])
    unmount()
  })
})

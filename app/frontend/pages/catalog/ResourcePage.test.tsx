import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { resourcePageProps as props } from '@/test/catalog'
import { renderPage } from '@/test/inertia'

import ResourcePage from './ResourcePage'

const url = '/resources/tafsir/tafsir-ibn-kathir'

describe('catalog/ResourcePage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('shows the type, name, status, language and licence status in the header', () => {
    renderPage(ResourcePage, { props, url })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Tafsir Ibn Kathir')
    const breadcrumb = screen.getByRole('navigation', { name: 'Breadcrumb' })
    expect(within(breadcrumb).getByRole('link', { name: 'Tafsirs' }).getAttribute('href')).toBe('/resources/tafsir')
    expect(screen.getByText('Stable')).toBeDefined()
    expect(screen.getAllByText('Licence not yet confirmed').length).toBeGreaterThan(0)
    expect(screen.getByText('English', { selector: 'span' })).toBeDefined()
    // The summary is a backfill's draft.
    expect(screen.getByText(/English tafsir, ayah by ayah/).textContent).toContain('(not yet reviewed)')
  })

  it('lists the files of the picked format with size, MD5 and a nofollow download link', () => {
    renderPage(ResourcePage, { props, url })

    const files = screen.getByRole('list', { name: 'Files' })
    expect(within(files).getAllByRole('listitem')).toHaveLength(2)
    expect(within(files).getByText('5.1 MB').getAttribute('title')).toBe('5347738 bytes')
    expect(within(files).getByText('1 MB')).toBeDefined()
    expect(within(files).getByText('d41d8cd98f00b204e9800998ecf8427e')).toBeDefined()
    expect(within(files).getAllByText(/MD5 \(hex\)/)).toHaveLength(2)
    const link = within(files).getByRole('link', { name: 'Download simple.sqlite, 5.1 MB' })
    expect(link.getAttribute('href')).toBe('/resources/tafsir/tafsir-ibn-kathir/download/11')
    expect(link.getAttribute('rel')).toBe('nofollow')

    fireEvent.click(screen.getByRole('button', { name: 'JSON' }))
    expect(within(files).getAllByRole('listitem')).toHaveLength(1)
    expect(within(files).getByText('812 bytes')).toBeDefined()
    expect(screen.getByRole('button', { name: 'JSON' }).getAttribute('aria-pressed')).toBe('true')
  })

  it('tells an anonymous visitor in sign-in mode that a download needs an account', () => {
    renderPage(ResourcePage, { props, url })

    expect(screen.getByText(/Downloads need a free account/)).toBeDefined()
  })

  it('offers sign-in for update emails in public mode', () => {
    renderPage(ResourcePage, { props: { ...props, downloadMode: 'public' }, url })

    const panel = screen.getByRole('complementary', { name: 'Download' })
    const signIn = within(panel).getByRole('link', { name: 'Sign in' })
    expect(signIn.getAttribute('href')).toBe(`/users/sign_in?user_return_to=${encodeURIComponent(url)}`)
    expect(screen.getByText(/to get an email when this resource is updated/)).toBeDefined()
  })

  it('shows the reason and no download link for a restricted resource', () => {
    renderPage(ResourcePage, {
      props: { ...props, canDownload: false, restriction: '<h5>Copyright notice</h5>Ask the publisher first.' },
      url,
    })

    const panel = screen.getByRole('complementary', { name: 'Download' })
    expect(within(panel).queryByRole('link', { name: /^Download/ })).toBeNull()
    expect(within(panel).getByText('Copyright notice')).toBeDefined()
    expect(screen.getByText('View only')).toBeDefined()
  })

  it('says so when the resource has no files', () => {
    renderPage(ResourcePage, { props: { ...props, files: [] }, url })

    expect(screen.getByText('This resource has no files to download yet.')).toBeDefined()
  })

  it('lists what it works with, requires first, and marks a drafted link as not yet reviewed', () => {
    renderPage(ResourcePage, { props, url })

    const section = screen.getByRole('region', { name: 'Works with' })
    expect(
      within(section)
        .getAllByRole('heading', { level: 3 })
        .map((h) => h.textContent),
    ).toEqual(['Requires', 'Pairs with'])
    const requires = within(section).getByRole('list', { name: 'Requires' })
    expect(within(requires).getByRole('link').getAttribute('href')).toBe('/resources/font/digital-khatt')
    expect(within(requires).getByText('Font · not yet reviewed')).toBeDefined()
    expect(within(within(section).getByRole('list', { name: 'Pairs with' })).getByText('Quran script')).toBeDefined()
  })

  it('opens the tab from the props and puts a picked tab in the URL', () => {
    const push = vi.spyOn(router, 'push').mockImplementation(() => {})
    renderPage(ResourcePage, { props: { ...props, tab: 'data' }, url: `${url}?tab=data` })

    expect(screen.getByRole('tab', { name: 'Data' }).getAttribute('aria-selected')).toBe('true')
    expect(screen.getByText('SQLite, JSON')).toBeDefined()
    expect(screen.getByRole('link', { name: 'the tafsir guide' }).getAttribute('href')).toBe('/docs/resource-tafsirs')

    // Radix tabs switch on mouse down.
    fireEvent.mouseDown(screen.getByRole('tab', { name: 'Licence' }))
    expect(push).toHaveBeenCalledWith(
      expect.objectContaining({ url: `${url}?tab=licence`, preserveState: true, preserveScroll: true }),
    )
    const [{ props: update }] = push.mock.calls[0]
    expect(typeof update === 'function' && update({ ...props, tab: 'data' }, {})).toMatchObject({ tab: 'licence' })

    fireEvent.mouseDown(screen.getByRole('tab', { name: 'Preview' }))
    expect(push).toHaveBeenLastCalledWith(expect.objectContaining({ url }))
  })

  it('has no Changelog tab without entries, and lists the entries when there are some', () => {
    const { unmount } = renderPage(ResourcePage, { props: { ...props, changelog: [] }, url })
    expect(screen.queryByRole('tab', { name: 'Changelog' })).toBeNull()
    unmount()

    renderPage(ResourcePage, { props: { ...props, tab: 'changelog' }, url })
    const entries = screen.getByRole('list', { name: 'Changelog' })
    expect(within(entries).getByRole('link', { name: 'Fixed footnotes' }).getAttribute('href')).toBe('/change_logs/31')
    expect(within(entries).getByText('4 March 2026')).toBeDefined()
  })

  it('says the licence is not yet confirmed on the Licence tab', () => {
    renderPage(ResourcePage, { props: { ...props, tab: 'licence' }, url })

    const panel = screen.getByRole('tabpanel')
    expect(within(panel).getByRole('heading', { name: 'Licence not yet confirmed' })).toBeDefined()
  })

  it('starts the download sign-in returned for in a hidden frame, and takes it out of the URL', () => {
    const replace = vi.spyOn(router, 'replace').mockImplementation(() => {})
    renderPage(ResourcePage, { props: { ...props, download: 12 }, url: `${url}?download=12` })

    expect(screen.getByTitle('Download of simple.json').getAttribute('src')).toBe(
      '/resources/tafsir/tafsir-ibn-kathir/download/12',
    )
    expect(replace).toHaveBeenCalledWith(expect.objectContaining({ url, preserveState: true }))
    // The history entry keeps no download, so Back to this page does not start it again.
    const [{ props: update }] = replace.mock.calls[0]
    expect(typeof update === 'function' && update({ ...props, download: 12 }, {})).toMatchObject({ download: null })
    expect(screen.getByRole('status').textContent).toBe('Your download of simple.json has started.')
  })

  it('starts no download without the parameter', () => {
    const replace = vi.spyOn(router, 'replace').mockImplementation(() => {})
    renderPage(ResourcePage, { props, url })

    expect(document.querySelector('iframe')).toBeNull()
    expect(replace).not.toHaveBeenCalled()
  })

  it('links to the content issue form', () => {
    renderPage(ResourcePage, { props, url })

    const link = screen.getByRole('link', { name: 'Report an issue with this resource' })
    expect(link.getAttribute('href')).toBe(props.issueUrl)
    expect(link.getAttribute('target')).toBe('_blank')
  })
})

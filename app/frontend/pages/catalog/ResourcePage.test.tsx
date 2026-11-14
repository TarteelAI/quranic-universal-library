import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { resourcePageProps as props } from '@/test/catalog'
import { renderPage } from '@/test/inertia'
import { layoutPreview } from '@/test/previews'

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

  it('shows the schemas and a code sample of the format doc on the Data tab, and the whole doc on the Docs tab', () => {
    const push = vi.spyOn(router, 'push').mockImplementation(() => {})
    const { unmount } = renderPage(ResourcePage, { props: { ...props, tab: 'data' }, url: `${url}?tab=data` })

    const schema = screen.getByRole('figure', { name: 'SQLite columns' })
    expect(
      within(schema)
        .getAllByRole('row')
        .map((row) => row.textContent),
    ).toEqual(['ColumnDescription', 'ayah_keythe ayah this row is for.', 'textthe tafsir.'])
    const example = screen.getByRole('region', { name: 'Example' })
    expect(within(example).getByText('{ "2:4": "2:3" }')).toBeDefined()
    fireEvent.click(screen.getByRole('button', { name: 'Docs tab' }))
    expect(push).toHaveBeenCalledWith(expect.objectContaining({ url: `${url}?tab=docs` }))
    unmount()

    renderPage(ResourcePage, { props: { ...props, tab: 'docs' }, url: `${url}?tab=docs` })
    expect(screen.getByRole('tab', { name: 'Docs' }).getAttribute('aria-selected')).toBe('true')
    const panel = screen.getByRole('tabpanel')
    expect(within(panel).getByRole('heading', { name: 'About tafsir data' })).toBeDefined()
    expect(within(panel).getByText('{ "2:4": "2:3" }')).toBeDefined()
  })

  it('says so on the Data tab when the format doc lists no fields, and when there is no format doc', () => {
    const { unmount } = renderPage(ResourcePage, {
      props: { ...props, tab: 'data', schemas: [], codeSample: null },
      url: `${url}?tab=data`,
    })
    expect(screen.getByText('The format guide does not list the fields of these files.')).toBeDefined()
    expect(screen.queryByRole('region', { name: 'Example' })).toBeNull()
    unmount()

    renderPage(ResourcePage, {
      props: { ...props, tab: 'data', formatGuide: null, schemas: [], codeSample: null },
      url: `${url}?tab=data`,
    })
    expect(screen.getByText('There is no format guide for this resource yet.')).toBeDefined()
    expect(screen.queryByRole('tab', { name: 'Docs' })).toBeNull()
  })

  it('shows the content notice on translations and tafsirs only', () => {
    const notice = { name: 'Important notice' }
    const withType = (type: string) => ({ ...props, resource: { ...props.resource, type } })

    for (const type of ['tafsir', 'translation']) {
      const { unmount } = renderPage(ResourcePage, { props: withType(type), url })
      const aside = screen.getByRole('complementary', notice)
      expect(aside.textContent).toContain(type === 'tafsir' ? 'No tafsir can' : 'No translation of the')
      expect(within(aside).getByRole('link', { name: 'please report it to us' }).getAttribute('href')).toBe(
        props.issueUrl,
      )
      unmount()
    }
    for (const type of ['transliteration', 'surah-info', 'recitation', 'quran-script']) {
      const { unmount } = renderPage(ResourcePage, { props: withType(type), url })
      expect(screen.queryByRole('complementary', notice)).toBeNull()
      unmount()
    }
  })

  it('shows the version and updated date in the download panel, and no empty label without them', () => {
    const { unmount } = renderPage(ResourcePage, { props, url })
    const panel = screen.getByRole('complementary', { name: 'Download' })
    expect(within(panel).getByText('Version').nextElementSibling?.textContent).toBe('1703808000')
    expect(within(panel).getByText('Updated').nextElementSibling?.textContent).toBe('29 December 2023')
    unmount()

    renderPage(ResourcePage, { props: { ...props, release: { version: null, updatedOn: null } }, url })
    const bare = screen.getByRole('complementary', { name: 'Download' })
    expect(within(bare).queryByText('Version')).toBeNull()
    expect(within(bare).queryByText('Updated')).toBeNull()
  })

  it('copies the full download URL of a file', async () => {
    const writeText = vi.fn(() => Promise.resolve())
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
    renderPage(ResourcePage, { props, url })

    const files = screen.getByRole('list', { name: 'Files' })
    const full = `${window.location.origin}/resources/tafsir/tafsir-ibn-kathir/download/11`
    expect(within(files).getByText(full)).toBeDefined()
    fireEvent.click(within(files).getAllByRole('button', { name: 'Copy link' })[0])
    expect(writeText).toHaveBeenCalledWith(full)
    expect(await within(files).findByRole('button', { name: 'Copied' })).toBeDefined()
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

  describe('the preview', () => {
    const layout = { ...props, resource: { ...props.resource, type: 'mushaf-layout', toParam: 'v2' } }
    const layoutUrl = '/resources/mushaf-layout/v2'

    it('pages by reloading only the preview prop, with the page in the URL', () => {
      Object.defineProperty(document, 'fonts', { value: { load: () => Promise.resolve([]) }, configurable: true })
      const get = vi.spyOn(router, 'get').mockImplementation(() => {})
      renderPage(ResourcePage, { props: { ...layout, preview: layoutPreview }, url: `${layoutUrl}?page=2` })

      fireEvent.click(screen.getByRole('button', { name: /Next page/ }))
      expect(get).toHaveBeenCalledWith(
        `${layoutUrl}?page=3`,
        {},
        expect.objectContaining({ only: ['preview'], preserveState: true, preserveScroll: true }),
      )
    })

    it('keeps the page shown when another tab opens', () => {
      const push = vi.spyOn(router, 'push').mockImplementation(() => {})
      renderPage(ResourcePage, { props: layout, url: `${layoutUrl}?page=7&download=x` })

      fireEvent.mouseDown(screen.getByRole('tab', { name: 'Data' }))
      expect(push).toHaveBeenCalledWith(expect.objectContaining({ url: `${layoutUrl}?tab=data&page=7` }))
    })
  })
})

import { act, fireEvent, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { BUNDLE_KEY, resetBundle } from '@/lib/bundle'
import { renderPage } from '@/test/inertia'
import { nav, signedInAuth } from '@/test/shell'
import type { CatalogBundle, CatalogBundleItem } from '@/types/serializers'

import { AddToBundle, BundleToggle, BundleTray, bundleText } from './bundle'
import { ResourceCard } from './resource-card'

const file = (id: number, name: string, formatLabel = 'JSON') => ({
  id,
  name,
  format: 'json' as const,
  formatLabel,
  byteSize: 2048,
  md5: 'abc',
})

const ibnKathir: CatalogBundleItem = {
  id: 1,
  restricted: false,
  resource: { id: 1, name: 'Tafsir Ibn Kathir', type: 'tafsir', toParam: 'ibn-kathir' },
  category: 'tafsir',
  files: [file(11, 'Tafsir Ibn Kathir JSON'), file(12, 'Tafsir Ibn Kathir SQLite', 'SQLite')],
}
const gone: CatalogBundleItem = { id: 2, restricted: false, resource: null, category: null, files: [] }
const restricted: CatalogBundleItem = {
  id: 3,
  restricted: true,
  resource: { id: 3, name: 'Closed tafsir', type: 'tafsir', toParam: 'closed' },
  category: 'tafsir',
  files: [],
}
const noFiles: CatalogBundleItem = {
  id: 4,
  restricted: false,
  resource: { id: 4, name: 'Empty layout', type: 'mushaf-layout', toParam: 'empty' },
  category: 'layout',
  files: [],
}

let fetchMock: ReturnType<typeof vi.fn>
function answer(items: CatalogBundleItem[], downloadMode: CatalogBundle['downloadMode'] = 'public') {
  fetchMock = vi.fn(() => Promise.resolve(new Response(JSON.stringify({ items, downloadMode }))))
  vi.stubGlobal('fetch', fetchMock)
}

const stored = () => JSON.parse(window.localStorage.getItem(BUNDLE_KEY) ?? 'null')
const count = () => screen.getByRole('button', { name: /^Bundle, / }).getAttribute('aria-label')

beforeEach(() => {
  window.localStorage.clear()
  resetBundle()
})
afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

function openTray() {
  fireEvent.click(screen.getByRole('button', { name: /^Bundle, / }))
  return screen.getByRole('dialog', { name: 'Bundle' })
}

describe('the bundle', () => {
  it('adds and removes from a card, a kit and a detail page, updating the header count and storage', () => {
    renderPage(
      () => (
        <>
          <BundleTray />
          <ResourceCard
            title="Sahih International"
            href="/resources/translation/1"
            category="translation"
            bundleId={7}
          />
          <AddToBundle ids={[1, 2]} label="Add kit to bundle" addedLabel="Kit is in your bundle" />
          <AddToBundle ids={[9]} />
        </>
      ),
      { props: {} },
    )

    expect(count()).toBe('Bundle, 0 resources')
    fireEvent.click(screen.getByRole('button', { name: 'Add Sahih International to bundle' }))
    expect(count()).toBe('Bundle, 1 resource')
    fireEvent.click(screen.getByRole('button', { name: 'Add kit to bundle' }))
    fireEvent.click(screen.getByRole('button', { name: 'Add to bundle' }))
    expect(count()).toBe('Bundle, 4 resources')
    expect(stored()).toEqual([7, 1, 2, 9])
    expect(
      screen.getByRole('button', { name: 'Remove Sahih International from bundle' }).getAttribute('aria-pressed'),
    ).toBe('true')

    fireEvent.click(screen.getByRole('button', { name: 'Kit is in your bundle' }))
    fireEvent.click(screen.getByRole('button', { name: 'In your bundle' }))
    fireEvent.click(screen.getByRole('button', { name: 'Remove Sahih International from bundle' }))
    expect(count()).toBe('Bundle, 0 resources')
    expect(stored()).toEqual([])
  })

  it('reads the stored list and follows a change made in another tab', () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1, 2, 'x', 2]))
    renderPage(() => <BundleTray />, { props: {} })
    expect(count()).toBe('Bundle, 2 resources')

    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([5]))
    act(() => window.dispatchEvent(new StorageEvent('storage', { key: BUNDLE_KEY })))
    expect(count()).toBe('Bundle, 1 resource')
  })

  it('works for the page when storage is blocked', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError')
    })
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError')
    })
    renderPage(() => <BundleToggle id={3} name="Closed tafsir" />, { props: {} })

    fireEvent.click(screen.getByRole('button', { name: 'Add Closed tafsir to bundle' }))
    expect(screen.getByRole('button', { name: 'Remove Closed tafsir from bundle' })).toBeTruthy()
  })

  it('shows nothing while the catalog pages are old pages', () => {
    renderPage(
      () => (
        <>
          <BundleTray />
          <BundleToggle id={1} name="Sahih International" />
          <AddToBundle ids={[1]} />
        </>
      ),
      { props: {}, shared: { nav: { ...nav, bundle: false } } },
    )
    expect(screen.queryAllByRole('button')).toEqual([])
  })
})

describe('the bundle tray', () => {
  it('lists each file with its download route and marks what can no longer be downloaded', async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1, 2, 3, 4]))
    answer([ibnKathir, gone, restricted, noFiles])
    renderPage(() => <BundleTray />, { props: {} })

    const tray = within(openTray())
    await tray.findByText('Tafsir Ibn Kathir')
    expect(fetchMock.mock.calls[0][0]).toBe('/bundle?ids=1%2C2%2C3%2C4')

    const files = within(tray.getByRole('list', { name: 'Files of Tafsir Ibn Kathir' })).getAllByRole('link')
    expect(files.map((link) => link.getAttribute('href'))).toEqual([
      '/resources/tafsir/ibn-kathir/download/11',
      '/resources/tafsir/ibn-kathir/download/12',
    ])
    expect(tray.getByRole('link', { name: 'Tafsir Ibn Kathir' }).getAttribute('href')).toBe(
      '/resources/tafsir/ibn-kathir',
    )
    expect(tray.getByText('This resource is no longer in the library.')).toBeTruthy()
    expect(tray.getByText(/publisher does not allow downloads/)).toBeTruthy()
    expect(tray.getByText(/has no files to download now/)).toBeTruthy()
    expect(tray.getAllByRole('link', { name: /^Download / })).toHaveLength(2)
    expect(tray.queryByText(/need a free account/)).toBeNull()

    fireEvent.click(tray.getByRole('button', { name: 'Remove the unavailable resource from bundle' }))
    expect(tray.queryByText('This resource is no longer in the library.')).toBeNull()
    expect(stored()).toEqual([1, 3, 4])
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('copies each resource name with the full URL of each of its files', async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1, 2, 3]))
    answer([ibnKathir, gone, restricted])
    const writeText = vi.fn(() => Promise.resolve())
    vi.stubGlobal('navigator', { ...navigator, clipboard: { writeText } })
    renderPage(() => <BundleTray />, { props: {} })

    const tray = within(openTray())
    fireEvent.click(await tray.findByRole('button', { name: 'Copy list' }))
    expect(writeText).toHaveBeenCalledWith(
      [
        'Tafsir Ibn Kathir',
        `${window.location.origin}/resources/tafsir/ibn-kathir/download/11`,
        `${window.location.origin}/resources/tafsir/ibn-kathir/download/12`,
      ].join('\n'),
    )
    expect(bundleText([ibnKathir, ibnKathir], 'https://qul.tarteel.ai')).toBe(
      [
        'Tafsir Ibn Kathir',
        'https://qul.tarteel.ai/resources/tafsir/ibn-kathir/download/11',
        'https://qul.tarteel.ai/resources/tafsir/ibn-kathir/download/12',
        '',
        'Tafsir Ibn Kathir',
        'https://qul.tarteel.ai/resources/tafsir/ibn-kathir/download/11',
        'https://qul.tarteel.ai/resources/tafsir/ibn-kathir/download/12',
      ].join('\n'),
    )
  })

  it('asks an anonymous visitor to sign in first in sign-in mode, and nobody else', async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1]))
    answer([ibnKathir], 'sign_in')
    const { unmount } = renderPage(() => <BundleTray />, { props: {}, url: '/kits/recitation' })

    const tray = within(openTray())
    const signIn = await tray.findByRole('link', { name: 'Sign in' })
    expect(signIn.getAttribute('href')).toBe('/users/sign_in?user_return_to=%2Fkits%2Frecitation')
    unmount()

    renderPage(() => <BundleTray />, { props: {}, shared: { auth: signedInAuth } })
    const signedIn = within(openTray())
    await signedIn.findByText('Tafsir Ibn Kathir')
    expect(signedIn.queryByText(/need a free account/)).toBeNull()
  })

  it('says so when the bundle is empty, and asks the server nothing', () => {
    answer([])
    renderPage(() => <BundleTray />, { props: {} })

    expect(within(openTray()).getByText(/Nothing here yet/)).toBeTruthy()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('says so when the lookup fails', async () => {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify([1]))
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    vi.stubGlobal(
      'fetch',
      vi.fn(() => Promise.resolve(new Response('', { status: 500 }))),
    )
    renderPage(() => <BundleTray />, { props: {} })

    const tray = within(openTray())
    await waitFor(() => expect(tray.getByText(/could not be loaded/)).toBeTruthy())
  })
})

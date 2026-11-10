import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { appsPageProps } from '@/test/site'

import AppsPage from './AppsPage'

describe('site/AppsPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('lists the apps with their links, platforms and resource type chips', () => {
    renderPage(AppsPage, { props: appsPageProps })

    expect(screen.getByRole('list', { name: 'Apps' }).children).toHaveLength(4)
    expect(screen.getByRole('link', { name: 'QuranWBW' }).getAttribute('href')).toBe('https://quranwbw.com')
    const uses = within(screen.getByRole('list', { name: 'QUL resources Waqfah uses' }))
    expect(uses.getAllByRole('link').map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['Quran script', '/resources/quran-script'],
      ['Translation', '/resources/translation'],
    ])
    expect(screen.getByText('F-Droid')).toBeDefined()
    expect(screen.getAllByRole('link', { name: /Submit your app/ })[0].getAttribute('href')).toBe(
      appsPageProps.submitUrl,
    )
  })

  it('puts a filter in the URL, and a second click on the chip removes it', () => {
    const get = vi.spyOn(router, 'get').mockImplementation(() => {})
    const { unmount } = renderPage(AppsPage, { props: appsPageProps })

    fireEvent.click(within(screen.getByRole('group', { name: 'Platform' })).getByRole('button', { name: 'Android' }))
    expect(get).toHaveBeenLastCalledWith(
      '/apps?platform=android',
      {},
      expect.objectContaining({ only: ['apps', 'filters'] }),
    )
    unmount()

    const filtered = { ...appsPageProps, filters: { platform: 'android' as const, type: 'translation' as const } }
    renderPage(AppsPage, { props: filtered })
    const chip = within(screen.getByRole('group', { name: 'Platform' })).getByRole('button', { name: 'Android' })
    expect(chip.getAttribute('aria-pressed')).toBe('true')
    fireEvent.click(chip)
    expect(get).toHaveBeenLastCalledWith('/apps?type=translation', {}, expect.anything())
  })

  it('says when no app matches', () => {
    renderPage(AppsPage, { props: { ...appsPageProps, apps: [], filters: { platform: 'ios', type: null } } })

    expect(screen.getByText('No app matches these filters')).toBeDefined()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(AppsPage, { props: appsPageProps })

    expect(logged).toEqual([])
    unmount()
  })
})

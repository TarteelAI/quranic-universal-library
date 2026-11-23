import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { profilePageProps } from '@/test/account'
import { renderPage } from '@/test/inertia'
import { requestsNav, signedInAuth } from '@/test/shell'

import ProfilePage from './ProfilePage'

const shared = { nav: requestsNav, auth: signedInAuth }

describe('account/ProfilePage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('shows who the user is, with a link to the account settings', () => {
    renderPage(ProfilePage, { props: profilePageProps, shared, url: '/profile' })

    expect(screen.getByRole('heading', { level: 1, name: 'Fake Reader' })).toBeDefined()
    expect(screen.getByText(/reader@example\.test/)).toBeDefined()
    expect(screen.getByText(/Member since November 2026/)).toBeDefined()
    expect(within(screen.getByRole('region', { name: 'About' })).getByText('Building a study app.')).toBeDefined()
    expect(screen.getByRole('link', { name: 'Edit profile' }).getAttribute('href')).toBe('/profile/edit')
  })

  it('has a tab for each list with its count, and no requests tab while that group is off', () => {
    const view = renderPage(ProfilePage, { props: profilePageProps, shared, url: '/profile' })

    const names = () => screen.getAllByRole('tab').map((tab) => tab.textContent)
    expect(names()).toEqual(['Downloads2', 'Contributions60', 'Edit access1', 'Requests2'])
    expect(screen.getByRole('tab', { name: /Downloads/ }).getAttribute('aria-selected')).toBe('true')

    view.unmount()
    renderPage(ProfilePage, {
      props: { ...profilePageProps, counts: { ...profilePageProps.counts, requests: null } },
      shared,
      url: '/profile',
    })
    expect(names()).toEqual(['Downloads2', 'Contributions60', 'Edit access1'])
  })

  it('lists the downloads with their state, linking only the ones that still have a page', () => {
    renderPage(ProfilePage, { props: profilePageProps, shared, url: '/profile' })

    const rows = within(screen.getByRole('list', { name: 'Downloads' })).getAllByRole('listitem')
    expect(rows).toHaveLength(2)
    const first = within(rows[0])
    expect(first.getByRole('link', { name: 'Saheeh International' }).getAttribute('href')).toBe(
      '/resources/translation/saheeh-international',
    )
    expect(first.getByText('Downloaded 20 November 2026')).toBeDefined()
    expect(first.getByText('Up to date')).toBeDefined()
    expect(within(rows[1]).queryByRole('link')).toBeNull()
    expect(within(rows[1]).getByText('Update available')).toBeDefined()
  })

  it('keeps the filter in the URL', () => {
    renderPage(ProfilePage, { props: profilePageProps, shared, url: '/profile?download_type=translation' })

    const filter = within(screen.getByRole('navigation', { name: 'Filter' }))
    expect(filter.getByRole('link', { name: 'All' }).getAttribute('href')).toBe('/profile')
    expect(filter.getByRole('link', { name: 'Tafsir' }).getAttribute('href')).toBe('/profile?download_type=tafsir')
    expect(filter.getByRole('link', { name: 'Translation' }).getAttribute('aria-current')).toBe('true')
  })

  it('pages through the contributions, keeping the tab and the filter', () => {
    renderPage(ProfilePage, {
      props: {
        ...profilePageProps,
        tab: 'contributions',
        page: 2,
        pages: 3,
        downloads: null,
        filter: { param: 'item_type', value: 'Tafsir', options: profilePageProps.filter!.options },
        contributions: [
          {
            id: 9,
            icon: 'TF',
            type: 'Tafsir',
            label: 'Tafsir Ibn Kathir',
            reference: '2:238',
            path: '/cms/tafsirs/9',
            date: '24 September 2026',
          },
        ],
      },
      shared,
      url: '/profile?tab=contributions&item_type=Tafsir&page=2',
    })

    const row = within(screen.getByRole('list', { name: 'Contributions' })).getByRole('listitem')
    expect(within(row).getByRole('link', { name: 'Tafsir Ibn Kathir' }).getAttribute('href')).toBe('/cms/tafsirs/9')
    expect(within(row).getByText('2:238 · 24 September 2026')).toBeDefined()
    const pages = within(screen.getByRole('navigation', { name: 'Pages' }))
    expect(pages.getByRole('link', { name: 'Previous' }).getAttribute('href')).toBe(
      '/profile?tab=contributions&item_type=Tafsir',
    )
    expect(pages.getByRole('link', { name: 'Next' }).getAttribute('href')).toBe(
      '/profile?tab=contributions&item_type=Tafsir&page=3',
    )
  })

  it('opens another tab with a visit that keeps the scroll position', () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    renderPage(ProfilePage, { props: profilePageProps, shared, url: '/profile' })

    const tab = screen.getByRole('tab', { name: /Requests/ })
    fireEvent.mouseDown(tab, { button: 0 })
    fireEvent.click(tab)

    expect(visit).toHaveBeenCalledWith('/profile?tab=requests', { preserveScroll: true })
  })

  it('shows an empty state with a next step when a list is empty', () => {
    renderPage(ProfilePage, {
      props: { ...profilePageProps, filter: null, downloads: [] },
      shared,
      url: '/profile',
    })

    expect(screen.getByText('No downloads yet')).toBeDefined()
    expect(screen.getByRole('link', { name: 'Browse the resources' }).getAttribute('href')).toBe('/resources')
  })
})

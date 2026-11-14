import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { requestsPageProps } from '@/test/requests'
import { requestsNav, signedInAuth } from '@/test/shell'

import RequestsPage from './RequestsPage'

const shared = { nav: requestsNav }

describe('requests/RequestsPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('lists each request with its status, type, language, date and votes', () => {
    renderPage(RequestsPage, { props: requestsPageProps, shared, url: '/requests?page=2' })

    const items = within(screen.getByRole('list', { name: 'Requests' })).getAllByRole('listitem')
    expect(items).toHaveLength(2)
    const first = within(items[0])
    expect(first.getByRole('heading', { name: 'Tafsir Ahsanul Bayan' })).toBeDefined()
    expect(first.getByText('Open')).toBeDefined()
    expect(first.getByText('Tafsir · Bengali · 13 November 2026')).toBeDefined()
    expect(within(items[1]).getByText('Planned')).toBeDefined()
    expect(within(items[1]).getByText('Translation · 13 November 2026')).toBeDefined()
  })

  it('keeps the sort in the URL and the paging links', () => {
    renderPage(RequestsPage, {
      props: { ...requestsPageProps, sort: 'date' },
      shared,
      url: '/requests?sort=date&page=2',
    })

    const sort = within(screen.getByRole('navigation', { name: 'Sort' }))
    expect(sort.getByRole('link', { name: 'Most votes' }).getAttribute('href')).toBe('/requests')
    expect(sort.getByRole('link', { name: 'Newest' }).getAttribute('aria-current')).toBe('true')
    const pages = within(screen.getByRole('navigation', { name: 'Pages' }))
    expect(pages.getByRole('link', { name: 'Previous' }).getAttribute('href')).toBe('/requests?sort=date')
    expect(pages.getByRole('link', { name: 'Next' }).getAttribute('href')).toBe('/requests?sort=date&page=3')
    expect(pages.getByText('Page 2 of 3')).toBeDefined()
  })

  it('asks a signed-out visitor to sign in to vote, back to this page', () => {
    renderPage(RequestsPage, { props: requestsPageProps, shared, url: '/requests?page=2' })

    const vote = screen.getByRole('link', { name: 'Sign in to vote for Hausa translation (1 vote)' })
    expect(vote.getAttribute('href')).toBe('/users/sign_in?user_return_to=%2Frequests%3Fpage%3D2')
  })

  it('votes and takes a vote back, reloading only the list', () => {
    const post = vi.spyOn(router, 'post').mockImplementation(() => {})
    const remove = vi.spyOn(router, 'delete').mockImplementation(() => {})
    renderPage(RequestsPage, { props: requestsPageProps, shared: { ...shared, auth: signedInAuth } })

    const voted = screen.getByRole('button', { name: 'Vote for Tafsir Ahsanul Bayan (12 votes)' })
    expect(voted.getAttribute('aria-pressed')).toBe('true')
    fireEvent.click(voted)
    expect(remove).toHaveBeenCalledWith(
      '/requests/7/vote',
      expect.objectContaining({ only: ['requests'], preserveScroll: true }),
    )

    fireEvent.click(screen.getByRole('button', { name: 'Vote for Hausa translation (1 vote)' }))
    expect(post).toHaveBeenCalledWith(
      '/requests/3/vote',
      {},
      expect.objectContaining({ only: ['requests'], preserveScroll: true }),
    )
  })

  it('opens the request dialog from its header button', () => {
    renderPage(RequestsPage, { props: requestsPageProps, shared, url: '/requests' })

    fireEvent.click(screen.getByRole('link', { name: 'Request a resource' }))
    expect(screen.getByRole('dialog', { name: 'Request a resource' })).toBeDefined()
  })

  it('says when there are no requests yet', () => {
    renderPage(RequestsPage, { props: { ...requestsPageProps, requests: [], total: 0, page: 1, pages: 1 }, shared })

    expect(screen.getByText('No requests yet')).toBeDefined()
    expect(screen.queryByRole('navigation', { name: 'Pages' })).toBeNull()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(RequestsPage, { props: requestsPageProps, shared })

    expect(logged).toEqual([])
    unmount()
  })
})

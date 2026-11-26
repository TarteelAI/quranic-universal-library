import { cleanup, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { nav } from '@/test/shell'
import { kitPageProps } from '@/test/start'

import KitPage from './KitPage'

describe('start/KitPage', () => {
  it('lists each item with its need, card, reason and alternative, in order', () => {
    renderPage(KitPage, { props: kitPageProps, url: '/kits/madani-reader' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Madani reader')
    expect(screen.getByText('1 translation · 1 tafsir')).toBeDefined()
    const items = within(screen.getByRole('list', { name: 'In Madani reader' })).getAllByRole('listitem')
    expect(items).toHaveLength(2)

    const first = within(items[0])
    expect(first.getByText('01')).toBeDefined()
    expect(first.getByText('English translation')).toBeDefined()
    expect(first.getByRole('link', { name: 'Sahih International' }).getAttribute('href')).toBe(
      '/resources/translation/sahih-international',
    )
    expect(first.getByText(/Clear, literal English/)).toBeDefined()
    expect(first.getByRole('link', { name: 'Swap for The Clear Quran' }).getAttribute('href')).toBe(
      '/resources/translation/the-clear-quran',
    )

    expect(within(items[1]).getByText('Navigation')).toBeDefined()
    expect(within(items[1]).queryByRole('link', { name: /^Swap for/ })).toBeNull()
  })

  it('links the kits index and the guided setup with the kit answers', () => {
    renderPage(KitPage, { props: kitPageProps, url: '/kits/madani-reader' })

    expect(screen.getByRole('link', { name: 'Starter kits' }).getAttribute('href')).toBe('/kits')
    expect(screen.getByRole('link', { name: 'build your own from these answers' }).getAttribute('href')).toBe(
      kitPageProps.setupPath,
    )
    expect(screen.getByRole('link', { name: /Change the answers/ }).getAttribute('href')).toBe(kitPageProps.setupPath)
    expect(screen.getByRole('button', { name: 'Copy link' })).toBeDefined()
  })

  it('downloads the kit as a zip once signed in, and has no bundle button', () => {
    renderPage(KitPage, { props: kitPageProps, url: '/kits/madani-reader' })
    expect(screen.getByRole('link', { name: 'Sign in to download' }).getAttribute('href')).toBe(
      '/users/sign_in?user_return_to=%2Fkits%2Fmadani-reader',
    )
    expect(screen.queryByRole('button', { name: 'Add kit to bundle' })).toBeNull()
    cleanup()

    renderPage(KitPage, { props: { ...kitPageProps, downloadMode: 'public' }, url: '/kits/madani-reader' })
    expect(screen.getByRole('button', { name: 'Download kit' })).toBeDefined()
  })

  it('has no download while the bundle lookup is off (the catalog group)', () => {
    renderPage(KitPage, { props: kitPageProps, shared: { nav: { ...nav, bundle: false } }, url: '/kits/madani-reader' })
    expect(screen.queryByRole('link', { name: 'Sign in to download' })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Download kit' })).toBeNull()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(KitPage, { props: kitPageProps, url: '/kits/madani-reader' })

    expect(logged).toEqual([])
    unmount()
  })
})

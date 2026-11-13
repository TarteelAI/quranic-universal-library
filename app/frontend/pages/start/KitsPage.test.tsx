import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { kitsPageProps } from '@/test/start'

import KitsPage from './KitsPage'

describe('start/KitsPage', () => {
  it('shows a card for each kit linking to its page, and links the guided setup', () => {
    renderPage(KitsPage, { props: kitsPageProps, url: '/kits' })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Starter kits2')
    const card = screen.getByRole('link', { name: /Madani reader/ })
    expect(card.getAttribute('href')).toBe('/kits/madani-reader')
    expect(
      within(card)
        .getAllByRole('listitem')
        .map((item) => item.textContent),
    ).toEqual(['KFGQPC V2 layout', 'Saheeh International'])
    expect(screen.getByRole('link', { name: /Recitation with highlighting/ }).getAttribute('href')).toBe(
      '/kits/recitation',
    )
    expect(screen.getByRole('link', { name: /Build your own/ }).getAttribute('href')).toBe('/start')
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(KitsPage, { props: kitsPageProps, url: '/kits' })

    expect(logged).toEqual([])
    unmount()
  })
})

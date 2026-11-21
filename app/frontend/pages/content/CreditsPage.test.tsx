import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { creditsProps } from '@/test/content'
import { hydratePage, renderPage } from '@/test/inertia'

import CreditsPage from './CreditsPage'

describe('content/CreditsPage', () => {
  it('shows the organizations with their logos and formatted descriptions', () => {
    renderPage(CreditsPage, { props: creditsProps, url: '/credits' })

    const organizations = within(screen.getByRole('region', { name: 'Organizations' }))
    expect(organizations.getByRole('link', { name: 'Tafsir Center' }).getAttribute('href')).toBe('https://tafsir.net/')
    expect(organizations.getByText('Quranic studies').tagName).toBe('EM')
    expect(organizations.getByText('No Logo Foundation').closest('a')).toBeNull()
    expect(organizations.getAllByRole('listitem')[0].querySelector('img')?.getAttribute('src')).toBe(
      '/rails/active_storage/blobs/redirect/abc/logo.png',
    )
  })

  it('names the people and projects, joining several with "and"', () => {
    renderPage(CreditsPage, { props: creditsProps, url: '/credits' })

    const items = within(screen.getByRole('region', { name: 'People and projects' })).getAllByRole('listitem')
    expect(items.map((item) => item.textContent)).toEqual([
      'Tanzil For preparing and auditing the Quran text.',
      'Sami Rifai and ReciteQuran.com For providing recitations.',
    ])
    expect(within(items[1]).getByText('Sami Rifai').closest('a')).toBeNull()
  })

  it('lists the code contributors', () => {
    renderPage(CreditsPage, { props: creditsProps, url: '/credits' })

    const code = within(screen.getByRole('region', { name: 'Code contributors' }))
    expect(code.getByRole('link', { name: /octocat/ }).textContent).toContain('1 contribution')
  })

  it('leaves out the code contributors when GitHub sent none', () => {
    renderPage(CreditsPage, { props: { ...creditsProps, codeContributors: [] }, url: '/credits' })

    expect(screen.queryByRole('region', { name: 'Code contributors' })).toBeNull()
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(CreditsPage, { props: creditsProps })

    expect(logged).toEqual([])
    unmount()
  })
})

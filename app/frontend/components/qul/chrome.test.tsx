import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { signedInAuth } from '@/test/shell'

import { SiteFooter, SiteHeader } from './chrome'

const Header = () => <SiteHeader />
const Footer = () => <SiteFooter />

describe('SiteHeader', () => {
  it('shows the icon-only logo, the menus, the search button and sign-in, and no theme switch or search field', () => {
    renderPage(Header, { props: {}, url: '/resources/tafsir?q=ibn' })

    const home = screen.getByRole('link', { name: 'QUL home' })
    expect(home.getAttribute('href')).toBe('/')
    expect(home.textContent?.trim()).toBe('')
    const menus = within(screen.getByRole('navigation', { name: 'Main' }))
    expect(menus.getByRole('button', { name: 'Resources' }).getAttribute('aria-current')).toBe('page')
    expect(menus.getByRole('button', { name: 'Contribute' }).getAttribute('aria-current')).toBeNull()
    expect(screen.getByRole('button', { name: 'Search resources' }).getAttribute('aria-haspopup')).toBe('dialog')
    expect(screen.getByRole('link', { name: 'Sign in' }).getAttribute('href')).toBe(
      '/users/sign_in?user_return_to=%2Fresources%2Ftafsir%3Fq%3Dibn',
    )
    expect(screen.queryByRole('searchbox')).toBeNull()
    expect(screen.queryByRole('radiogroup', { name: 'Theme' })).toBeNull()
  })

  it('shows the signed-in user and signs out with a DELETE form post', () => {
    renderPage(Header, { props: {}, shared: { auth: signedInAuth } })

    const account = screen.getByRole('button', { name: 'Fake' })
    expect(account.textContent).toBe('FRFake')
    expect(screen.queryByRole('link', { name: 'Sign in' })).toBeNull()
    const form = document.querySelector<HTMLFormElement>('form[action="/users/sign_out"]')
    expect(form?.getAttribute('method')).toBe('post')
    expect(form?.querySelector<HTMLInputElement>('input[name="_method"]')?.value).toBe('delete')
  })
})

describe('SiteFooter', () => {
  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
    localStorage.clear()
    document.documentElement.classList.remove('dark')
  })

  it('shows the logo lockup and the tagline', () => {
    renderPage(Footer, { props: {} })

    const footer = screen.getByRole('contentinfo')
    expect(within(footer).getByText('QUL')).toBeDefined()
    expect(within(footer).getByText('Quranic Universal Library')).toBeDefined()
    expect(within(footer).getByText(/Open, verified Quran data and tools\./)).toBeDefined()
  })

  it('switches between the light, dark and system theme and marks the choice', () => {
    localStorage.setItem('qul-theme', 'dark')
    vi.stubGlobal(
      'matchMedia',
      vi.fn(() => ({ matches: false })),
    )
    renderPage(Footer, { props: {} })

    const theme = within(screen.getByRole('radiogroup', { name: 'Theme' }))
    expect(theme.getByRole('radio', { name: 'Dark theme' }).getAttribute('aria-checked')).toBe('true')

    fireEvent.click(theme.getByRole('radio', { name: 'System theme' }))
    expect(theme.getByRole('radio', { name: 'System theme' }).getAttribute('aria-checked')).toBe('true')
    expect(theme.getByRole('radio', { name: 'Dark theme' }).getAttribute('aria-checked')).toBe('false')
    expect(localStorage.getItem('qul-theme')).toBe('system')
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    fireEvent.click(theme.getByRole('radio', { name: 'Dark theme' }))
    expect(localStorage.getItem('qul-theme')).toBe('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)
  })

  it('visits a new page with Inertia and loads an old page in full', () => {
    const visit = vi.spyOn(router, 'visit').mockImplementation(() => {})
    renderPage(Footer, { props: {} })

    fireEvent.click(screen.getByRole('link', { name: 'All docs' }))
    expect(visit).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('link', { name: 'All resources' }))
    expect(visit).toHaveBeenCalledWith('/resources', expect.anything())
  })
})

import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { signedInAuth } from '@/test/shell'

import { SiteFooter, SiteHeader } from './chrome'

const Header = () => <SiteHeader />
const Footer = () => <SiteFooter />

describe('SiteHeader', () => {
  it('shows the icon-only logo, the menus, the search button and sign-in, and no theme toggle or search field', () => {
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
    expect(screen.queryByRole('button', { name: /theme/ })).toBeNull()
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
  afterEach(() => vi.restoreAllMocks())

  it('has the theme toggle', () => {
    renderPage(Footer, { props: {} })

    expect(screen.getByRole('button', { name: /theme/ })).toBeDefined()
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

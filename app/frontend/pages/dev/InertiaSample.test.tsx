import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { renderPage } from '@/test/inertia'

import InertiaSample from './InertiaSample'

describe('dev/InertiaSample', () => {
  it('shows the heading and the deferred count once it is loaded', () => {
    renderPage(InertiaSample, { props: { heading: 'Sample heading', publishedResourceCount: 12 } })

    expect(screen.getByRole('heading', { level: 1, name: 'Sample heading' })).toBeDefined()
    expect(screen.getByTestId('resource-count').textContent).toBe('Published resources: 12')
  })

  it('links to sign in with a return to this page when signed out', () => {
    renderPage(InertiaSample, { props: { heading: 'Sample heading' } })

    expect(screen.getByRole('link', { name: 'Sign in' }).getAttribute('href')).toBe(
      '/users/sign_in?user_return_to=%2F__dev%2Finertia_sample',
    )
  })

  it('offers a sign-out form post when signed in', () => {
    renderPage(InertiaSample, { props: { heading: 'Sample heading' }, shared: { signedIn: true } })

    const form = screen.getByRole('button', { name: 'Sign out' }).closest('form')
    expect(form?.getAttribute('action')).toBe('/users/sign_out')
    expect(form?.querySelector<HTMLInputElement>('input[name="_method"]')?.value).toBe('delete')
  })
})

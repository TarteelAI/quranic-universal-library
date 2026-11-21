import { router } from '@inertiajs/react'
import { fireEvent, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { settingsPageProps } from '@/test/account'
import { renderPage } from '@/test/inertia'
import { requestsNav, signedInAuth } from '@/test/shell'

import SettingsPage from './SettingsPage'

const shared = { nav: requestsNav, auth: signedInAuth }

describe('account/SettingsPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('sends the name and the about text on their own, as user fields', () => {
    const patch = vi.spyOn(router, 'patch').mockImplementation(() => {})
    renderPage(SettingsPage, { props: settingsPageProps, shared, url: '/profile/edit' })

    fireEvent.change(screen.getByLabelText('First name'), { target: { value: 'Faked' } })
    fireEvent.click(screen.getByRole('button', { name: 'Save profile' }))

    expect(patch).toHaveBeenCalledTimes(1)
    const [url, data] = patch.mock.calls[0]
    expect(url).toBe('/profile')
    expect(data).toEqual({ user: { first_name: 'Faked', last_name: 'Reader', about_me: 'Building a study app.' } })
  })

  it('asks for the current password only once the email or the password changes', () => {
    renderPage(SettingsPage, { props: settingsPageProps, shared, url: '/profile/edit' })

    const save = screen.getByRole('button', { name: 'Save email and password' })
    const current = screen.getByLabelText('Current password')
    expect(save).toHaveProperty('disabled', true)
    expect(current).toHaveProperty('required', false)

    fireEvent.change(screen.getByLabelText('New password'), { target: { value: 'a-new-password' } })
    expect(save).toHaveProperty('disabled', false)
    expect(current).toHaveProperty('required', true)
  })

  it('shows what was typed in a password field on request', () => {
    renderPage(SettingsPage, { props: settingsPageProps, shared, url: '/profile/edit' })

    const field = screen.getByLabelText('Current password')
    expect(field.getAttribute('type')).toBe('password')
    fireEvent.click(screen.getAllByRole('button', { name: 'Show the password' })[0])
    expect(field.getAttribute('type')).toBe('text')
  })

  it('says which email waits for confirmation', () => {
    renderPage(SettingsPage, {
      props: { ...settingsPageProps, emailStatus: 'pending', unconfirmedEmail: 'new@example.test' },
      shared,
      url: '/profile/edit',
    })

    expect(screen.getByText('Change pending')).toBeDefined()
    expect(screen.getByText('Waiting for you to verify new@example.test.')).toBeDefined()
  })
})

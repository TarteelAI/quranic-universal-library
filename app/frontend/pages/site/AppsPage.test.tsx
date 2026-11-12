import { router } from '@inertiajs/react'
import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { signedInAuth } from '@/test/shell'
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

  it('shows a signed-out visitor the whole submission form, disabled, with a sign-in link back to it', () => {
    renderPage(AppsPage, { props: appsPageProps })
    fireEvent.click(screen.getAllByRole('button', { name: /Submit your app/ })[0])

    const dialog = screen.getByRole('dialog', { name: 'Submit your app' })
    for (const field of ['App name', 'Link', 'Icon (optional)', 'Contact email']) {
      expect(within(dialog).getByLabelText(field).matches(':disabled')).toBe(true)
    }
    expect(within(dialog).getByRole('button', { name: 'Recitation' }).matches(':disabled')).toBe(true)
    expect(within(dialog).getByRole('checkbox').matches(':disabled')).toBe(true)
    expect(within(dialog).getByRole('button', { name: 'Submit app' }).matches(':disabled')).toBe(true)
    expect(within(dialog).getByRole('link', { name: 'Sign in' }).getAttribute('href')).toBe(
      '/users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1',
    )
  })

  it('opens the form from ?submit, and posts the fields under `app` for a signed-in visitor', () => {
    const post = vi.spyOn(router, 'post').mockImplementation(() => {})
    renderPage(AppsPage, { props: appsPageProps, shared: { auth: signedInAuth }, url: '/apps?submit=1' })

    const dialog = within(screen.getByRole('dialog', { name: 'Submit your app' }))
    expect(dialog.queryByRole('link', { name: 'Sign in' })).toBeNull()
    fireEvent.change(dialog.getByLabelText('App name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.click(dialog.getByRole('button', { name: 'iOS' }))
    fireEvent.click(dialog.getByRole('button', { name: 'Translation' }))
    fireEvent.change(dialog.getByLabelText('Contact email'), { target: { value: 'maker@example.test' } })
    fireEvent.click(dialog.getByRole('checkbox'))
    const icon = new File(['png'], 'noor.png', { type: 'image/png' })
    fireEvent.change(dialog.getByLabelText('Icon (optional)'), { target: { files: [icon] } })
    fireEvent.click(dialog.getByRole('button', { name: 'Submit app' }))

    expect(post).toHaveBeenCalledWith(
      '/apps',
      {
        app: {
          name: 'Noor',
          url: 'https://noor.example',
          platforms: ['ios'],
          uses: ['translation'],
          contact: 'maker@example.test',
          consent: true,
          icon,
        },
      },
      expect.objectContaining({ preserveScroll: true }),
    )
  })

  it('shows the server errors beside their fields and keeps what was typed', async () => {
    vi.spyOn(router, 'post').mockImplementation((_url, _data, options) => {
      options?.onError?.({
        platforms: ['Platforms must include at least one platform'],
        consent: ['Consent must be given'],
      })
    })
    renderPage(AppsPage, { props: appsPageProps, shared: { auth: signedInAuth }, url: '/apps?submit=1' })

    const dialog = within(screen.getByRole('dialog', { name: 'Submit your app' }))
    fireEvent.change(dialog.getByLabelText('App name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.change(dialog.getByLabelText('Contact email'), { target: { value: 'maker@example.test' } })
    fireEvent.click(dialog.getByRole('button', { name: 'Submit app' }))

    await waitFor(() => expect(dialog.getByText('Platforms must include at least one platform')).toBeDefined())
    expect(dialog.getByRole('group', { name: 'Platforms' }).getAttribute('aria-describedby')).toBe(
      'app-platforms-error',
    )
    expect(dialog.getByText('Consent must be given')).toBeDefined()
    expect(dialog.getByLabelText('App name')).toHaveProperty('value', 'Noor')
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(AppsPage, { props: appsPageProps })

    expect(logged).toEqual([])
    unmount()
  })
})

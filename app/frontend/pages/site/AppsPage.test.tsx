import { router } from '@inertiajs/react'
import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { hydratePage, renderPage } from '@/test/inertia'
import { signedInAuth } from '@/test/shell'
import { appsPageProps } from '@/test/site'

import AppsPage from './AppsPage'

describe('site/AppsPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('lists the apps with their type or platforms, their links and resource type chips', () => {
    renderPage(AppsPage, { props: appsPageProps })

    expect(screen.getByRole('list', { name: 'Apps' }).children).toHaveLength(4)
    expect(screen.getByRole('link', { name: 'QuranWBW' }).getAttribute('href')).toBe('https://quranwbw.com')
    const uses = within(screen.getByRole('list', { name: 'QUL resources Waqfah uses' }))
    expect(uses.getAllByRole('link').map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['Quran script', '/resources/quran-script'],
      ['Translation', '/resources/translation'],
    ])
    expect(screen.getByText('F-Droid')).toBeDefined()

    const links = (name: string) =>
      within(screen.getByRole('link', { name }).closest('li')!)
        .getAllByRole('link')
        .slice(1, -1)
        .filter((link) => !link.getAttribute('href')!.startsWith('/'))
        .map((link) => [link.textContent, link.getAttribute('href')])
    expect(links('QuranWBW')).toEqual([
      ['quranwbw.com', 'https://quranwbw.com'],
      ['Source', 'https://github.com/marwan/quranwbw'],
    ])
    expect(links('Nimaz')).toEqual([
      ['nimaz.arshadshah.com', 'https://nimaz.arshadshah.com'],
      ['Google Play', 'https://play.google.com/store/apps/details?id=com.arshadshah.nimaz'],
      ['Source', 'https://github.com/arshad-shah/Nimaz'],
    ])
    expect(screen.getByRole('link', { name: 'Quran Validator' }).closest('li')!.textContent).toContain('Library')
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

    const filtered = {
      ...appsPageProps,
      filters: { projectType: null, platform: 'android' as const, type: 'translation' as const },
    }
    renderPage(AppsPage, { props: filtered })
    const chip = within(screen.getByRole('group', { name: 'Platform' })).getByRole('button', { name: 'Android' })
    expect(chip.getAttribute('aria-pressed')).toBe('true')
    fireEvent.click(chip)
    expect(get).toHaveBeenLastCalledWith('/apps?type=translation', {}, expect.anything())

    fireEvent.click(within(screen.getByRole('group', { name: 'Type' })).getByRole('button', { name: 'Library' }))
    expect(get).toHaveBeenLastCalledWith(
      '/apps?project_type=library&platform=android&type=translation',
      {},
      expect.anything(),
    )
  })

  it('says when no app matches', () => {
    renderPage(AppsPage, {
      props: { ...appsPageProps, apps: [], filters: { projectType: null, platform: 'ios', type: null } },
    })

    expect(screen.getByText('No app matches these filters')).toBeDefined()
  })

  it('shows a signed-out visitor the whole submission form, disabled, with a sign-in link back to it', () => {
    renderPage(AppsPage, { props: appsPageProps })
    fireEvent.click(screen.getAllByRole('button', { name: /Submit your app/ })[0])

    const dialog = screen.getByRole('dialog', { name: 'Submit your app' })
    for (const field of ['Name', 'Link', 'Description', 'Source code (optional)', 'Icon (optional)', 'Contact email']) {
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
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.change(dialog.getByLabelText('Description'), { target: { value: 'Reads the Quran.' } })
    expect(dialog.queryByLabelText('App Store link (optional)')).toBeNull()
    fireEvent.click(dialog.getByRole('button', { name: 'iOS' }))
    fireEvent.change(dialog.getByLabelText('App Store link (optional)'), {
      target: { value: 'https://apps.apple.com/app/id1' },
    })
    expect(dialog.queryByLabelText('Google Play link (optional)')).toBeNull()
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
          project_type: 'app',
          description: 'Reads the Quran.',
          platforms: ['ios'],
          app_store_url: 'https://apps.apple.com/app/id1',
          play_store_url: '',
          source_url: '',
          uses: ['translation'],
          contact: 'maker@example.test',
          consent: true,
          icon,
        },
      },
      expect.objectContaining({ preserveScroll: true }),
    )
  })

  it('asks a library for no platforms or store links, and sends none', () => {
    const post = vi.spyOn(router, 'post').mockImplementation(() => {})
    renderPage(AppsPage, { props: appsPageProps, shared: { auth: signedInAuth }, url: '/apps?submit=1' })

    const dialog = within(screen.getByRole('dialog', { name: 'Submit your app' }))
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.change(dialog.getByLabelText('Description'), { target: { value: 'A Quran package.' } })
    fireEvent.change(dialog.getByLabelText('Contact email'), { target: { value: 'maker@example.test' } })
    fireEvent.click(dialog.getByRole('button', { name: 'Android' }))
    fireEvent.change(dialog.getByLabelText('Google Play link (optional)'), {
      target: { value: 'https://play.google.com/store/apps/details?id=noor' },
    })
    fireEvent.click(within(dialog.getByRole('group', { name: 'What is it?' })).getByRole('button', { name: 'Library' }))
    expect(dialog.queryByRole('group', { name: 'Platforms' })).toBeNull()
    expect(dialog.queryByLabelText('Google Play link (optional)')).toBeNull()
    fireEvent.change(dialog.getByLabelText('Source code (optional)'), {
      target: { value: 'https://github.com/example/noor' },
    })
    fireEvent.click(dialog.getByRole('button', { name: 'Submit app' }))

    expect(post).toHaveBeenCalledWith(
      '/apps',
      {
        app: expect.objectContaining({
          project_type: 'library',
          platforms: [],
          play_store_url: '',
          source_url: 'https://github.com/example/noor',
        }),
      },
      expect.anything(),
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
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.change(dialog.getByLabelText('Description'), { target: { value: 'Reads the Quran.' } })
    fireEvent.change(dialog.getByLabelText('Contact email'), { target: { value: 'maker@example.test' } })
    fireEvent.click(dialog.getByRole('button', { name: 'Submit app' }))

    await waitFor(() => expect(dialog.getByText('Platforms must include at least one platform')).toBeDefined())
    expect(dialog.getByRole('group', { name: 'Platforms' }).getAttribute('aria-describedby')).toBe(
      'app-platforms-error',
    )
    expect(dialog.getByText('Consent must be given')).toBeDefined()
    expect(dialog.getByLabelText('Name')).toHaveProperty('value', 'Noor')
  })

  it('shows the refusal of a submission over the daily limit', async () => {
    vi.spyOn(router, 'post').mockImplementation((_url, _data, options) => {
      options?.onError?.({ base: ['You can send at most 3 apps a day. Try again tomorrow.'] })
    })
    renderPage(AppsPage, { props: appsPageProps, shared: { auth: signedInAuth }, url: '/apps?submit=1' })

    const dialog = within(screen.getByRole('dialog', { name: 'Submit your app' }))
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Noor' } })
    fireEvent.change(dialog.getByLabelText('Link'), { target: { value: 'https://noor.example' } })
    fireEvent.change(dialog.getByLabelText('Description'), { target: { value: 'Reads the Quran.' } })
    fireEvent.change(dialog.getByLabelText('Contact email'), { target: { value: 'maker@example.test' } })
    fireEvent.click(dialog.getByRole('button', { name: 'Submit app' }))

    await waitFor(() =>
      expect(dialog.getByRole('alert').textContent).toBe('You can send at most 3 apps a day. Try again tomorrow.'),
    )
    expect(dialog.getByLabelText('Name')).toHaveProperty('value', 'Noor')
  })

  it('hydrates the server HTML without a mismatch', async () => {
    const { logged, unmount } = await hydratePage(AppsPage, { props: appsPageProps })

    expect(logged).toEqual([])
    unmount()
  })
})

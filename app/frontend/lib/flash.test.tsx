import { router } from '@inertiajs/react'
import { act, configure, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { toast } from 'sonner'

import { SiteShell } from '@/components/layout'
import { hydratePage, renderPage } from '@/test/inertia'

const Page = () => <SiteShell>Page body</SiteShell>
const toasts = () => screen.getByRole('region', { name: /^Notifications/ })
const shown = () => [...toasts().querySelectorAll('[data-sonner-toast]')].map((item) => item.textContent)

describe('the flash as toasts', () => {
  afterEach(() => {
    configure({ reactStrictMode: false })
    act(() => void toast.dismiss())
  })

  // First in the file: Inertia's router reports a later flash to the first app it rendered only.
  it('shows nothing without a flash, and one toast for a flash that arrives later', async () => {
    renderPage(Page, { props: {} })
    await act(async () => {})
    expect(shown()).toEqual([])

    act(() => router.flash({ notice: 'The request was sent.' }))
    await waitFor(() => expect(shown()).toEqual(['The request was sent.']))

    // The same flash again (a deferred props response copies it) updates the toast in place.
    act(() => router.flash({ notice: 'The request was sent.' }))
    await act(async () => new Promise((resolve) => setTimeout(resolve, 50)))
    expect(shown()).toEqual(['The request was sent.'])
  })

  // Each visit mounts the shell and its Toaster again, and sonner replays the toasts still open
  // to a new Toaster: without the dismissal, a message came back after every visit.
  it('closes the open toasts when the shell unmounts, so the next page does not show them again', async () => {
    const first = renderPage(Page, { props: {}, flash: { notice: 'Your account has been updated.' } })
    await waitFor(() => expect(shown()).toEqual(['Your account has been updated.']))
    first.unmount()

    renderPage(Page, { props: {} })
    await act(async () => new Promise((resolve) => setTimeout(resolve, 50)))
    expect(shown()).toEqual([])
  })

  it('shows the notice and the alert once each, in StrictMode too, outside the page flow', async () => {
    configure({ reactStrictMode: true })
    renderPage(Page, { props: {}, flash: { notice: 'Signed in successfully.', alert: 'The link has expired.' } })

    await waitFor(() => expect(shown()).toHaveLength(2))
    expect(shown().sort()).toEqual(['Signed in successfully.', 'The link has expired.'])
    expect(toasts().querySelector('[data-type="success"]')?.textContent).toBe('Signed in successfully.')
    expect(toasts().querySelector('[data-type="error"]')?.textContent).toBe('The link has expired.')
    expect(toasts().getAttribute('aria-live')).toBe('polite')
    expect(screen.getByRole('main').contains(toasts())).toBe(false)
    expect(screen.queryByRole('button', { name: 'Close the message' })).toBeNull()
  })

  it('shows the flash of the first page load after hydration, with no mismatch', async () => {
    const hydrated = await hydratePage(Page, { props: {}, flash: { notice: 'Signed in successfully.' } })

    await waitFor(() => expect(shown()).toEqual(['Signed in successfully.']))
    expect(hydrated.logged).toEqual([])
    hydrated.unmount()
    document.body.innerHTML = ''
  })
})

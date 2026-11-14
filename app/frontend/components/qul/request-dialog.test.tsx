import { router, usePage } from '@inertiajs/react'
import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { requestsNav, signedInAuth } from '@/test/shell'

import { RequestCard, RequestDialogProvider } from './request-dialog'

// A page with the shell's dialog and a request card, as the catalog and type pages have.
function CardPage() {
  return (
    <RequestDialogProvider>
      <RequestCard link={usePage().props.nav.request} />
    </RequestDialogProvider>
  )
}

const FIELDS = ['What is missing?', 'Language or script (optional)', 'What are you building?']

// Fills the required fields (the browser sends no form with an empty one) and sends the form.
function send(dialog: ReturnType<typeof within>) {
  fireEvent.change(dialog.getByLabelText('What is missing?'), { target: { value: 'Hausa' } })
  fireEvent.change(dialog.getByLabelText('What are you building?'), { target: { value: 'A study app' } })
  fireEvent.click(dialog.getByRole('button', { name: 'Send request' }))
}

describe('the request dialog', () => {
  afterEach(() => vi.restoreAllMocks())

  it('is not there while the requests group is off: the card links to the GitHub form', () => {
    renderPage(CardPage, { props: {}, url: '/resources?request=new' })

    expect(screen.queryByRole('dialog')).toBeNull()
    const link = screen.getByRole('link', { name: 'Request a resource' })
    expect(link.getAttribute('href')).toContain('resource_request.yml')
    expect(link.getAttribute('target')).toBe('_blank')
  })

  it('opens from the card for a signed-out visitor: the whole form disabled, sign-in back to it open', () => {
    renderPage(CardPage, { props: {}, shared: { nav: requestsNav }, url: '/resources?q=hausa' })
    const card = screen.getByRole('link', { name: 'Request a resource' })
    expect(card.getAttribute('href')).toBe('/requests?request=new')
    fireEvent.click(card)

    const dialog = within(screen.getByRole('dialog', { name: 'Request a resource' }))
    for (const field of FIELDS) expect(dialog.getByLabelText(field).matches(':disabled')).toBe(true)
    expect(dialog.getByRole('button', { name: 'Tafsir' }).matches(':disabled')).toBe(true)
    expect(dialog.getByRole('button', { name: 'Send request' }).matches(':disabled')).toBe(true)
    expect(dialog.getByRole('link', { name: 'Sign in' }).getAttribute('href')).toBe(
      '/users/sign_in?user_return_to=%2Fresources%3Fq%3Dhausa%26request%3Dnew',
    )
  })

  it('opens from ?request=new and posts the fields under `request` for a signed-in visitor', () => {
    const post = vi.spyOn(router, 'post').mockImplementation(() => {})
    renderPage(CardPage, {
      props: {},
      shared: { nav: requestsNav, auth: signedInAuth },
      url: '/resources/tafsir?request=new',
    })

    const dialog = within(screen.getByRole('dialog', { name: 'Request a resource' }))
    expect(dialog.queryByRole('link', { name: 'Sign in' })).toBeNull()
    expect(dialog.getByRole('group', { name: 'What kind of resource?' }).textContent).toBe('TranslationTafsirOther')
    fireEvent.click(dialog.getByRole('button', { name: 'Tafsir' }))
    fireEvent.change(dialog.getByLabelText('What is missing?'), { target: { value: 'Tafsir Ahsanul Bayan' } })
    fireEvent.change(dialog.getByLabelText('Language or script (optional)'), { target: { value: 'Bengali' } })
    fireEvent.change(dialog.getByLabelText('What are you building?'), { target: { value: 'A study app' } })
    fireEvent.click(dialog.getByRole('button', { name: 'Send request' }))

    expect(post).toHaveBeenCalledWith(
      '/requests',
      {
        request: {
          title: 'Tafsir Ahsanul Bayan',
          description: 'A study app',
          resource_type: 'tafsir',
          language: 'Bengali',
        },
      },
      expect.objectContaining({ preserveScroll: true }),
    )
  })

  it('shows the server errors beside their fields, and the daily limit as a whole', async () => {
    vi.spyOn(router, 'post').mockImplementation((_url, _data, options) => {
      options?.onError?.({
        resource_type: ['Resource type must be chosen from the list'],
        base: ['You can send at most 5 requests a day. Try again tomorrow.'],
      })
    })
    renderPage(CardPage, { props: {}, shared: { nav: requestsNav, auth: signedInAuth }, url: '/?request=new' })

    const dialog = within(screen.getByRole('dialog', { name: 'Request a resource' }))
    send(dialog)

    await waitFor(() => expect(dialog.getByText('Resource type must be chosen from the list')).toBeDefined())
    expect(dialog.getByRole('group', { name: 'What kind of resource?' }).getAttribute('aria-describedby')).toBe(
      'request-resource_type-error',
    )
    expect(dialog.getByRole('alert').textContent).toBe('You can send at most 5 requests a day. Try again tomorrow.')
    expect(dialog.getByLabelText('What is missing?')).toHaveProperty('value', 'Hausa')
  })

  it('says the request was received and links to the newest requests', async () => {
    vi.spyOn(router, 'post').mockImplementation((_url, _data, options) => {
      options?.onSuccess?.({} as never)
    })
    renderPage(CardPage, { props: {}, shared: { nav: requestsNav, auth: signedInAuth }, url: '/?request=new' })

    send(within(screen.getByRole('dialog', { name: 'Request a resource' })))

    const dialog = within(await screen.findByRole('dialog', { name: 'Request received' }))
    expect(dialog.getByRole('link', { name: 'See all requests' }).getAttribute('href')).toBe('/requests?sort=date')
  })
})

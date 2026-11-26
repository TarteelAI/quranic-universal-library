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
    expect(dialog.getByRole('group', { name: 'What kind of resource?' }).textContent).toBe('TranslationTafsirFontOther')
    fireEvent.click(dialog.getByRole('button', { name: 'Tafsir' }))
    fireEvent.change(dialog.getByLabelText('What is missing?'), { target: { value: 'Tafsir Ahsanul Bayan' } })
    fireEvent.change(dialog.getByLabelText('Author or translator'), { target: { value: 'Salahuddin Yusuf' } })
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
          author: 'Salahuddin Yusuf',
        },
      },
      expect.objectContaining({ preserveScroll: true }),
    )
  })

  it('asks for what each type needs: an author for a work, a file or link for a font', () => {
    const post = vi.spyOn(router, 'post').mockImplementation(() => {})
    renderPage(CardPage, { props: {}, shared: { nav: requestsNav, auth: signedInAuth }, url: '/?request=new' })
    const dialog = within(screen.getByRole('dialog', { name: 'Request a resource' }))

    // Before a type is chosen there is no author or source.
    expect(dialog.queryByLabelText(/Author/)).toBeNull()
    expect(dialog.queryByText(/Source/)).toBeNull()

    fireEvent.click(dialog.getByRole('button', { name: 'Translation' }))
    expect(dialog.getByLabelText('Author or translator').matches(':required')).toBe(true)
    expect(dialog.getByText('Book details (optional)').closest('details')?.open).toBe(false)
    expect(dialog.getByText('Source and licence (optional)').closest('details')?.open).toBe(false)
    fireEvent.change(dialog.getByLabelText('Author or translator'), { target: { value: 'Muhsin Khan' } })

    fireEvent.click(dialog.getByRole('button', { name: 'Other' }))
    expect(dialog.getByLabelText('Author (optional)').matches(':required')).toBe(false)

    fireEvent.click(dialog.getByRole('button', { name: 'Font' }))
    expect(dialog.queryByLabelText(/Author/)).toBeNull()
    expect(dialog.getByText('Source: the font file or a link to it').closest('details')?.open).toBe(true)
    const font = new File(['wOF2'], 'nastaliq.woff2')
    fireEvent.change(dialog.getByLabelText('Source files'), { target: { files: [font] } })
    fireEvent.change(dialog.getByLabelText('Link to the source'), { target: { value: 'https://example.test/f' } })
    send(dialog)

    // The author typed for the translation is not sent with a font.
    expect(post).toHaveBeenCalledWith(
      '/requests',
      {
        request: {
          title: 'Hausa',
          description: 'A study app',
          resource_type: 'font',
          language: '',
          source_url: 'https://example.test/f',
          source_files: [font],
        },
      },
      expect.anything(),
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

  it('opens the source group when the server finds an error in it', async () => {
    vi.spyOn(router, 'post').mockImplementation((_url, _data, options) => {
      options?.onError?.({
        source_files: ['Source files must be PDF, Word, text or font files (TTF, OTF, WOFF, WOFF2)'],
      })
    })
    renderPage(CardPage, { props: {}, shared: { nav: requestsNav, auth: signedInAuth }, url: '/?request=new' })
    const dialog = within(screen.getByRole('dialog', { name: 'Request a resource' }))
    fireEvent.click(dialog.getByRole('button', { name: 'Other' }))
    send(dialog)

    await waitFor(() => expect(dialog.getByText(/Source files must be PDF/)).toBeDefined())
    expect(dialog.getByText('Source and licence (optional)').closest('details')?.open).toBe(true)
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

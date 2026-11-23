// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { renderPageOnServer } from '@/test/inertia'
import { requestsPageProps } from '@/test/requests'
import { requestsNav } from '@/test/shell'

import RequestsPage from './RequestsPage'

describe('requests/RequestsPage on the server', () => {
  it('renders the list, its sort and its pages without browser globals', async () => {
    const { body } = await renderPageOnServer(RequestsPage, {
      props: requestsPageProps,
      shared: { nav: requestsNav },
      url: '/requests?page=2',
    })

    expect(body).toContain('Resource requests')
    expect(body).toContain('Tafsir Ahsanul Bayan')
    expect(body).toContain('Planned')
    expect(body).toMatch(/aria-current="true"[^>]*>Most votes/)
    expect(body).toContain('href="/requests?page=3"')
  })

  it('renders a page that opens the request dialog (?request=new) without browser globals', async () => {
    const { body } = await renderPageOnServer(RequestsPage, {
      props: requestsPageProps,
      shared: { nav: requestsNav },
      url: '/requests?request=new',
    })

    expect(body).toContain('Resource requests')
  })
})

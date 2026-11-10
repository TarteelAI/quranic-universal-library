// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { catalogPageProps } from '@/test/catalog'
import { renderPageOnServer } from '@/test/inertia'

import CatalogPage from './CatalogPage'

describe('catalog/CatalogPage on the server', () => {
  it('renders the results without browser globals', async () => {
    const { body } = await renderPageOnServer(CatalogPage, { props: catalogPageProps })

    expect(body).toContain('Resources')
    expect(body).toContain('Sahih International')
  })
})

// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { typePageProps } from '@/test/catalog'
import { renderPageOnServer } from '@/test/inertia'

import TypePage from './TypePage'

describe('catalog/TypePage on the server', () => {
  it('renders the type and its cards without browser globals', async () => {
    const { body } = await renderPageOnServer(TypePage, { props: typePageProps })

    expect(body).toContain('Translations')
    expect(body).toContain('Sahih International')
  })
})

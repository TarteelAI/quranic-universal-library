// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { layoutPageProps, typePageProps } from '@/test/catalog'
import { renderPageOnServer } from '@/test/inertia'

import TypePage from './TypePage'

describe('catalog/TypePage on the server', () => {
  it('renders the type and its cards without browser globals', async () => {
    const { body } = await renderPageOnServer(TypePage, { props: typePageProps })

    expect(body).toContain('Translations')
    expect(body).toContain('Sahih International')
    expect(body).toContain('href="/docs/resource-translations"')
  })

  it('renders the pick block, the comparison table and the collapsed older versions', async () => {
    const { body } = await renderPageOnServer(TypePage, { props: layoutPageProps })

    expect(body).toContain('Which one should I pick?')
    expect(body).toContain('Suggested, not yet reviewed')
    expect(body).toContain('<table')
    expect(body).toContain('KFGQPC V2 layout (Old)')
  })
})

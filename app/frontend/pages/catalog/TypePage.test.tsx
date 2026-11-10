import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { typePageProps } from '@/test/catalog'
import { renderPage } from '@/test/inertia'

import TypePage from './TypePage'

describe('catalog/TypePage', () => {
  it('shows the type title, its description and the resource count', () => {
    renderPage(TypePage, { props: typePageProps })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Translations2')
    expect(screen.getByText('Translations of the Quran in many languages.')).toBeDefined()
  })

  it('shows one card per resource, linking to its detail page with plain links', () => {
    renderPage(TypePage, { props: typePageProps })

    const cards = within(screen.getByRole('list', { name: 'Translations' })).getAllByRole('article')
    expect(cards).toHaveLength(2)
    expect(screen.getByRole('link', { name: 'Sahih International' }).getAttribute('href')).toBe(
      '/resources/translation/sahih-international',
    )
    expect(screen.getByText('Translation · English · Ayah by Ayah')).toBeDefined()
    expect(screen.getByText('Translation · Word by word')).toBeDefined()
    expect(screen.getByText('1 file')).toBeDefined()
  })

  it('links to every type page and marks the current one', () => {
    renderPage(TypePage, { props: typePageProps })

    const nav = screen.getByRole('navigation', { name: 'Other resource types' })
    expect(within(nav).getByRole('link', { name: 'Tafsirs' }).getAttribute('href')).toBe('/resources/tafsir')
    expect(within(nav).getByRole('link', { name: 'Translations' }).getAttribute('aria-current')).toBe('page')
  })

  it('says so when no resource of the type is published', () => {
    renderPage(TypePage, { props: { ...typePageProps, resources: [] } })

    expect(screen.getByText('No resources of this type are published yet.')).toBeDefined()
  })
})

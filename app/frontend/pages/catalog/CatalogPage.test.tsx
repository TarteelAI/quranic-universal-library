import { screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { catalogPageProps } from '@/test/catalog'
import { renderPage } from '@/test/inertia'

import CatalogPage from './CatalogPage'

describe('catalog/CatalogPage', () => {
  it('shows the result count and one card per result, linking to its detail page', () => {
    renderPage(CatalogPage, { props: catalogPageProps })

    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Resources2')
    const cards = within(screen.getByRole('list', { name: 'Resources' })).getAllByRole('article')
    expect(cards).toHaveLength(2)
    expect(screen.getByRole('link', { name: 'Tafsir Ibn Kathir' }).getAttribute('href')).toBe(
      '/resources/tafsir/tafsir-ibn-kathir',
    )
    expect(screen.getByText('Translation · English · Ayah by ayah')).toBeDefined()
    expect(screen.getByText('Tafsir · Multiple ayahs')).toBeDefined()
  })

  it('links to every type page', () => {
    renderPage(CatalogPage, { props: catalogPageProps })

    const nav = screen.getByRole('navigation', { name: 'Resource types' })
    expect(within(nav).getByRole('link', { name: 'Tafsirs' }).getAttribute('href')).toBe('/resources/tafsir')
  })

  it('says so when nothing matches', () => {
    renderPage(CatalogPage, { props: { ...catalogPageProps, results: [], total: 0 } })

    expect(screen.getByText('No resources match this search.')).toBeDefined()
  })
})

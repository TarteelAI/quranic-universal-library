import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { CardPreview } from '@/components/previews/card-preview'

import { ResourceCard } from './resource-card'
import { StatusBadge } from './status-badge'

const href = '/resources/translation/sahih-international'

function card() {
  return screen.getByTestId('resource-card')
}

describe('ResourceCard', () => {
  it('shows the preview, a small type icon beside the facts, the summary, the status and the formats', () => {
    render(
      <ResourceCard
        title="Sahih International"
        href={href}
        category="translation"
        facts={['Translation', 'English']}
        summary="English translation of the Quran, ayah by ayah."
        status={<StatusBadge status="beta" label="Beta" />}
        formats={['JSON', 'SQLite']}
        preview={<CardPreview kind="text" url={`${href}/preview`} />}
      />,
    )

    expect(within(card()).getByTestId('card-preview').dataset.kind).toBe('text')
    expect(screen.getByRole('link', { name: 'Sahih International' }).getAttribute('href')).toBe(href)
    const facts = screen.getByText('Translation · English')
    expect(facts.querySelector('.text-cat-translation svg')).not.toBeNull()
    expect(screen.getByText('English translation of the Quran, ayah by ayah.')).toBeDefined()
    expect(screen.getByText('Beta')).toBeDefined()
    expect(screen.getByText('JSON · SQLite')).toBeDefined()
    expect(card().querySelectorAll('svg')).toHaveLength(1)
  })

  it('leaves no empty space for a missing summary, status or formats', () => {
    render(<ResourceCard title="Word by word in Urdu" href={href} category="translation" summary={null} />)

    const body = card().lastElementChild!
    expect(body.children).toHaveLength(1)
    expect(card().querySelector('p.line-clamp-2')).toBeNull()
    expect(card().querySelector('.font-mono')).toBeNull()
  })

  it('shows the formats alone when the status is the default', () => {
    render(<ResourceCard title="Sahih International" href={href} category="translation" formats={['JSON']} />)

    const footer = screen.getByText('JSON').parentElement!
    expect(footer.children).toHaveLength(1)
  })

  it('shows the type icon as a tile beside the title when the type has no preview', () => {
    render(
      <ResourceCard
        title="Surah info in English"
        href="/resources/surah-info/en"
        category="tafsir"
        facts={['Surah info', 'English']}
        summary="An introduction to each surah."
        formats={['JSON']}
      />,
    )

    expect(screen.queryByTestId('card-preview')).toBeNull()
    const tile = card().querySelector('.bg-cat-tafsir-subtle')
    expect(tile?.querySelector('svg')).not.toBeNull()
    expect(screen.getByText('Surah info · English').querySelector('svg')).toBeNull()
    expect(screen.getByText('An introduction to each surah.')).toBeDefined()
  })

  it('dims the preview of an older resource', () => {
    render(
      <ResourceCard
        title="Old layout"
        href="/resources/mushaf-layout/old"
        category="layout"
        muted
        preview={<CardPreview kind="layout" url="/resources/mushaf-layout/old/preview" />}
      />,
    )

    expect(screen.getByTestId('card-preview').parentElement?.className).toContain('grayscale')
  })
})

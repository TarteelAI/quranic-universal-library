import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { nav } from '@/test/shell'

import { MegaMenu, MobileNav } from './nav'

const Menus = () => <MegaMenu menus={nav.menus} url="/resources" />
const Sheet = () => <MobileNav menus={nav.menus} url="/resources" />

// Opens a menu the way a keyboard does (a mouse click on the trigger visits the section's page).
function openMenu(label: string) {
  fireEvent.click(screen.getByRole('button', { name: label }))
  return within(screen.getByRole('navigation', { name: 'Main' }))
}

describe('MegaMenu', () => {
  // Radix sizes the open panel with a ResizeObserver, which jsdom does not have
  beforeEach(() =>
    vi.stubGlobal(
      'ResizeObserver',
      class {
        observe() {}
        unobserve() {}
        disconnect() {}
      },
    ),
  )
  afterEach(() => vi.unstubAllGlobals())

  it('lists a dense menu under its group headings, each link with an icon and a one-line description', () => {
    renderPage(Menus, { props: {}, url: '/resources' })
    const menu = openMenu('Contribute')

    expect(menu.getByText('Mushaf & scripts')).toBeDefined()
    expect(menu.getByText('Translations & tafsir')).toBeDefined()
    const tool = menu.getByRole('link', { name: /^Tajweed rules/ })
    expect(tool.getAttribute('href')).toBe('/tajweed_words')
    expect(tool.textContent).toBe('Tajweed rulesRules marked on each letter.')
    expect(tool.querySelector('svg.lucide-palette')).not.toBeNull()
  })

  it("shows a dense menu's side rail as a row of links beside the overview link", () => {
    renderPage(Menus, { props: {}, url: '/resources' })
    const menu = openMenu('Contribute')

    expect(menu.getByRole('link', { name: 'All contribution tools' }).getAttribute('href')).toBe('/tools')
    expect(menu.getByRole('link', { name: 'Changelog' }).getAttribute('href')).toBe('/change_logs')
    const github = menu.getByRole('link', { name: 'GitHub' })
    expect(github.getAttribute('target')).toBe('_blank')
    // The rail's headings are not shown in a dense menu
    expect(menu.queryByText('Help improve the data')).toBeNull()
    expect(menu.queryByText('Community')).toBeNull()
  })

  it.each([
    ['Contribute', 'Mushaf & scripts', 'All contribution tools'],
    ['Resources', 'Resource types', 'Browse all resources'],
  ])(
    'lets the %s links scroll inside the panel, with the overview row outside the scroll',
    (label, heading, overview) => {
      renderPage(Menus, { props: {}, url: '/resources' })
      const menu = openMenu(label)

      const scroller = menu.getByText(heading).closest('.overflow-y-auto')
      expect(scroller?.parentElement?.className).toContain('max-h-[calc(100dvh-5.5rem)]')
      expect(scroller?.contains(menu.getByRole('link', { name: overview }))).toBe(false)
    },
  )

  it('keeps the side rail with its headings in a menu that is not dense', () => {
    renderPage(Menus, { props: {}, url: '/resources' })
    const menu = openMenu('Resources')

    expect(menu.getByText('Jump to')).toBeDefined()
    expect(menu.getByRole('link', { name: 'How to download' })).toBeDefined()
  })
})

describe('MobileNav', () => {
  it('lists a dense menu under all its headings, without the tool icons', () => {
    renderPage(Sheet, { props: {}, url: '/resources' })
    fireEvent.click(screen.getByRole('button', { name: 'Contribute' }))
    const section = within(screen.getByRole('region', { name: 'Contribute' }))

    for (const heading of ['Mushaf & scripts', 'Translations & tafsir', 'Help improve the data', 'Community'])
      expect(section.getByText(heading)).toBeDefined()
    const tool = section.getByRole('link', { name: 'Tajweed rules' })
    expect(tool.querySelector('svg')).toBeNull()
    expect(section.getByRole('link', { name: /All contribution tools/ }).getAttribute('href')).toBe('/tools')
  })
})

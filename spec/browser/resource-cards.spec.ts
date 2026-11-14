import type { Locator, Page } from '@playwright/test'

import { expect, test } from './support/test'

// Resource cards (story 002-10) on the development clone: every type's cards show the preview
// kind of their type (Previews::Card::KINDS), or the type icon beside the title where the type
// has no card preview, and type headers carry the type icon.

const KINDS: Record<string, string | null> = {
  recitation: 'recitation',
  'mushaf-layout': 'layout',
  'quran-script': 'script',
  font: 'font',
  translation: 'text',
  transliteration: 'text',
  tafsir: 'text',
  'surah-info': null,
  morphology: null,
  mutashabihat: null,
  'similar-ayah': null,
  'ayah-topics': null,
  'ayah-theme': null,
  'quran-metadata': null,
}

// The first cards loaded in each type page's check.
const LOADED = 4

function typeOf(href: string) {
  return new URL(href, 'http://localhost').pathname.split('/')[2]
}

// Each shown card: its type, its preview well's kind and state (or none), and whether its type
// icon is a tile beside the title.
function cards(page: Page) {
  return page.locator('[data-testid="resource-card"]:visible').evaluateAll((articles) =>
    articles.map((card) => {
      const well = card.querySelector<HTMLElement>('[data-testid="card-preview"]')
      return {
        href: card.querySelector('h3 a')!.getAttribute('href')!,
        kind: well?.dataset.kind ?? null,
        state: well?.dataset.state ?? 'none',
        tile: card.querySelector('span.size-10 > svg') !== null,
      }
    }),
  )
}

// Each element drawn with a colour palette: the palette's name, the font families it and its
// children are drawn in, and the families the palette rule of that name lists (none: no rule).
function palettes(page: Page) {
  return page.evaluate(() => {
    const css = Array.from(document.querySelectorAll('style'))
      .map((style) => style.textContent)
      .join('\n')
    const unquote = (family: string) => family.trim().replace(/^['"]|['"]$/g, '')
    return Array.from(document.querySelectorAll<HTMLElement>('[style*="font-palette"]')).map((element) => {
      const name = element.style.fontPalette
      const drawn = [element, ...element.querySelectorAll<HTMLElement>('[style*="font-family"]')]
        .map((node) => node.style.fontFamily)
        .filter(Boolean)
        .map(unquote)
      const rule = css.match(new RegExp(`@font-palette-values ${name}\\{font-family:([^;]+);`))
      return { name, drawn, listed: rule ? rule[1].split(',').map(unquote) : [] }
    })
  })
}

function expectOwnPalettes(drawn: Awaited<ReturnType<typeof palettes>>) {
  for (const palette of drawn) {
    expect(palette.listed, palette.name).not.toEqual([])
    expect(
      palette.drawn.some((family) => palette.listed.includes(family)),
      palette.name,
    ).toBe(true)
  }
}

async function settled(page: Page) {
  // A type page asks for a screenful of previews at once; on a busy machine that takes a while.
  await expect(page.locator('[data-testid="card-preview"][data-state="loading"]')).toHaveCount(0, { timeout: 30_000 })
  await page.waitForLoadState('networkidle')
}

// Until the page hydrates no card watches the viewport, and a card scrolled past by then stays
// waiting, so each card is held on screen until it has seen it.
async function loadFirst(page: Page, list: Locator, count = LOADED) {
  const shown = await list.count()
  for (let index = 0; index < Math.min(count, shown); index++) {
    const card = list.nth(index)
    await card.scrollIntoViewIfNeeded()
    await expect(card.locator('[data-testid="card-preview"][data-state="waiting"]')).toHaveCount(0, { timeout: 30_000 })
  }
  await settled(page)
}

test.describe('resource cards', () => {
  for (const [type, kind] of Object.entries(KINDS)) {
    test(`${type}: every card has the ${kind ?? 'no-preview'} form, and the header the type icon`, async ({
      page,
    }, testInfo) => {
      await page.goto(`/resources/${type}`)
      const header = page.getByRole('heading', { level: 1 }).locator('xpath=../..')
      await expect(header.locator('> span > svg')).toBeVisible()

      const list = page.locator('[data-testid="resource-card"]:visible')
      await expect(list.first()).toBeVisible()
      await loadFirst(page, list)

      const shown = await cards(page)
      expect(shown.length).toBeGreaterThan(0)
      for (const card of shown) {
        expect(typeOf(card.href), card.href).toBe(type)
        if (kind) {
          // A failed preview removes the well; the card then shows the small icon only.
          expect(card.kind === kind || card.state === 'none', card.href).toBe(true)
          expect(card.tile, card.href).toBe(false)
        } else {
          expect(card.state, card.href).toBe('none')
          expect(card.tile, card.href).toBe(true)
        }
      }
      if (kind) {
        const first = shown.slice(0, LOADED)
        expect(first.filter((card) => card.state === 'loaded').length, 'loaded previews').toBeGreaterThan(0)
        expect(first.filter((card) => card.state === 'waiting')).toEqual([])
      }

      expectOwnPalettes(await palettes(page))

      await list.first().scrollIntoViewIfNeeded()
      await page.screenshot({ path: `tmp/playwright/resource-cards/${type}-${testInfo.project.name}.png` })
      const counts = shown.reduce<Record<string, number>>((all, card) => {
        all[card.state] = (all[card.state] ?? 0) + 1
        return all
      }, {})
      console.log(`[resource cards] ${testInfo.project.name} ${type}: ${shown.length} cards, ${JSON.stringify(counts)}`)
    })
  }

  test('the catalog gives each card the form of its type, with its summary, status and formats', async ({
    page,
  }, testInfo) => {
    await page.goto('/resources?sort=name')
    const list = page.locator('[data-testid="resource-card"]:visible')
    await expect(list).toHaveCount(24)
    await loadFirst(page, list)

    for (const card of await cards(page)) {
      const kind = KINDS[typeOf(card.href)]
      if (kind) expect(card.kind === kind || card.state === 'none', card.href).toBe(true)
      else expect(card.tile && card.state === 'none', card.href).toBe(true)
    }

    // Formats are the card's last line, in capitals; a summary sits above them.
    const formats = await list.locator('.font-mono').allTextContents()
    expect(formats.length).toBeGreaterThan(0)
    expect(formats.every((text) => /^[A-Z ·]+$/i.test(text))).toBe(true)

    await list.first().scrollIntoViewIfNeeded()
    await page.screenshot({ path: `tmp/playwright/resource-cards/catalog-${testInfo.project.name}.png` })
  })

  // Each type has one V4 Tajweed card; a search for v4 shows the layout, script and font ones.
  test('the V4 Tajweed cards of one page each keep their own colour palette', async ({ page }) => {
    await page.goto('/resources?q=v4')
    const list = page.locator('[data-testid="resource-card"]:visible')
    await expect(list.first()).toBeVisible()
    await loadFirst(page, list, await list.count())

    const drawn = await palettes(page)
    expect(drawn.length).toBeGreaterThan(1)
    expectOwnPalettes(drawn)
    expect(new Set(drawn.map((palette) => palette.name)).size).toBe(drawn.length)
    console.log(`[resource cards] V4 palettes on /resources?q=v4: ${drawn.length}`)
  })
})

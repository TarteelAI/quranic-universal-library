import type { Page, Request } from '@playwright/test'

import { expect, test } from './support/test'

// Card previews (Previews::Card) on the development clone: a card asks for its preview, and the
// browser for the preview's fonts, only once the card comes near the viewport.

const PREVIEW = /\/resources\/[^/]+\/[^/]+\/preview$/
const FONT = /\.(woff2?|ttf|otf)(\?|$)/

function record(page: Page) {
  const previews: string[] = []
  const fonts: string[] = []
  page.on('request', (request: Request) => {
    const path = new URL(request.url()).pathname
    if (PREVIEW.test(path)) previews.push(path)
    // Preview fonts come from the CDN; the interface fonts are this app's own.
    else if (FONT.test(path) && new URL(request.url()).hostname !== 'localhost') fonts.push(request.url())
  })
  return { previews, fonts }
}

// Each card's detail path and the state of its preview well, in the card list `name`.
function wells(page: Page, name: string) {
  return page.getByRole('list', { name, exact: true }).evaluate((list) =>
    Array.from(list.querySelectorAll('article')).map((card) => ({
      path: card.querySelector('h3 a')!.getAttribute('href')!,
      state: card.querySelector<HTMLElement>('[data-testid="card-preview"]')?.dataset.state ?? 'none',
    })),
  )
}

// Every URL the page's @font-face rules name.
function declaredFonts(page: Page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('style')).flatMap((style) =>
      Array.from(style.textContent!.matchAll(/url\('([^']+)'\)/g), (match) => match[1]),
    ),
  )
}

async function settled(page: Page) {
  await expect(page.locator('[data-testid="card-preview"][data-state="loading"]')).toHaveCount(0)
  await page.waitForLoadState('networkidle')
}

test('a type page loads previews and fonts only for the cards on screen', async ({ page }) => {
  const seen = record(page)
  const list = 'Quran scripts'
  const requested = (cards: { path: string; state: string }[]) =>
    new Set(cards.filter((card) => card.state !== 'waiting').map((card) => `${card.path}/preview`))

  // The comparison table fills the first screen: no card is on it.
  await page.goto('/resources/quran-script')
  await settled(page)
  expect((await wells(page, list)).every((card) => card.state === 'waiting')).toBe(true)
  expect(seen.previews).toEqual([])
  expect(seen.fonts).toEqual([])

  const cards = page.getByRole('list', { name: list, exact: true }).locator('article')
  await cards.first().scrollIntoViewIfNeeded()
  await expect(cards.first().getByTestId('card-preview')).toHaveAttribute('data-state', 'loaded')
  await settled(page)
  const top = await wells(page, list)
  expect(top.at(-1)!.state).toBe('waiting')
  expect(new Set(seen.previews)).toEqual(requested(top))
  expect(seen.fonts.length).toBeGreaterThan(0)
  expect(await declaredFonts(page)).toEqual(expect.arrayContaining(seen.fonts))
  const before = { previews: seen.previews.length, fonts: seen.fonts.length }

  // A jump to the last card skips the cards in between: they never ask for anything.
  await cards.last().scrollIntoViewIfNeeded()
  await expect(cards.last().getByTestId('card-preview')).toHaveAttribute('data-state', 'loaded')
  await settled(page)
  const after = await wells(page, list)
  expect(after.at(-1)!.state).toBe('loaded')
  expect(after.some((card) => card.state === 'waiting')).toBe(true)
  expect(seen.previews.length).toBeGreaterThan(before.previews)
  expect(new Set(seen.previews)).toEqual(requested(after))
  expect(new Set(seen.previews).size).toBe(seen.previews.length)
  expect(await declaredFonts(page)).toEqual(expect.arrayContaining(seen.fonts))
  console.log(
    `[card previews] ${after.length} cards: on load 0 previews and 0 fonts; at the first card ${before.previews} ` +
      `previews and ${before.fonts} fonts; after the jump to the last card ${seen.previews.length} previews and ` +
      `${seen.fonts.length} fonts`,
  )
})

test('the catalog asks for the previews of the first screen only, and a failed one leaves its card plain', async ({
  page,
  stubs,
}) => {
  const seen = record(page)
  let failed = ''
  await stubs.route(PREVIEW, async (route) => {
    failed ||= new URL(route.request().url()).pathname
    if (new URL(route.request().url()).pathname === failed) await route.fulfill({ status: 500 })
    else await route.continue()
  })
  await page.goto('/resources')
  await settled(page)

  const cards = await wells(page, 'Resources')
  expect(cards).toHaveLength(24)
  expect(seen.previews.length).toBeGreaterThan(0)
  expect(seen.previews.length).toBeLessThan(cards.filter((card) => card.state !== 'none').length)

  const plain = cards.find((card) => `${card.path}/preview` === failed)!
  expect(plain.state).toBe('none')
  await expect(page.locator(`h3 a[href="${plain.path}"]`)).toBeVisible()
  console.log(
    `[card previews] /resources: ${cards.length} cards, ${cards.filter((card) => card.state !== 'none').length} ` +
      `preview wells after one failed; on load ${seen.previews.length} previews and ${seen.fonts.length} fonts`,
  )
})

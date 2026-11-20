import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

// The home page's library section and contribution tools (story 002-12) on the development
// clone: a card per category, the sampled ones each loading a part of their sample's preview once
// near the screen, and the tool cards.

type Props = {
  samples: { type: string; category: string; toParam: string; name: string }[]
  categories: { key: string; label: string; count: number }[]
  tools: { label: string; href: string }[]
}

const PREVIEW_PROPS: Record<string, string> = {
  recitation: 'recitationPreview',
  'mushaf-layout': 'mushafLayoutPreview',
  translation: 'translationPreview',
  morphology: 'morphologyPreview',
  'ayah-topics': 'ayahTopicsPreview',
}

async function home(page: Page) {
  const response = await page.goto('/')
  const html = await response!.text()
  const props: Props = JSON.parse((await page.locator('script[data-page="app"]').textContent())!).props
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
  return { html, props }
}

const card = (page: Page, category: string) => page.locator(`[data-testid="library-card"][data-category="${category}"]`)

test('each sampled card loads its preview once near the screen, and links its sample', async ({ page }) => {
  const partials: string[] = []
  page.on('request', (request) => {
    const only = request.headers()['x-inertia-partial-data']
    if (only) partials.push(only)
  })
  const { html, props } = await home(page)
  expect(props.samples.map((sample) => sample.type)).toEqual(Object.keys(PREVIEW_PROPS))
  // The first response holds no preview.
  for (const prop of Object.values(PREVIEW_PROPS)) expect(html).not.toContain(`"${prop}"`)
  // Nor does the page ask for one while the library is off screen.
  await page.waitForLoadState('networkidle')
  expect(partials).toEqual([])

  for (const sample of props.samples) {
    const sampled = card(page, sample.category)
    await sampled.scrollIntoViewIfNeeded()
    await expect(sampled.getByTestId('sample-preview')).toHaveAttribute('data-type', sample.type, { timeout: 30_000 })
    // The one-column topics card names no sample.
    if (sample.type === 'ayah-topics') continue
    await expect(sampled.getByRole('link', { name: sample.name, exact: true })).toHaveAttribute(
      'href',
      `/resources/${sample.type}/${sample.toParam}`,
    )
  }
  expect([...partials].sort()).toEqual(Object.values(PREVIEW_PROPS).sort())
})

test('the audio card plays an ayah at a time, plays from an ayah, and pauses', async ({ page }) => {
  await home(page)
  const audioCard = card(page, 'audio')
  await audioCard.scrollIntoViewIfNeeded()
  const play = audioCard.getByRole('button', { name: /^Play Surah/ })
  await expect(play).toBeVisible({ timeout: 30_000 })
  const audio = audioCard.locator('audio')

  await play.click()
  await expect
    .poll(() => audio.evaluate((element: HTMLAudioElement) => element.currentTime), { timeout: 30_000 })
    .toBeGreaterThan(0)
  await expect(audioCard.locator('[data-active-ayah]')).toHaveAttribute('data-active-ayah', /^1:\d$/)

  await audioCard.getByRole('button', { name: 'Play from ayah 1:5' }).click()
  await expect(audioCard.locator('[data-active-ayah]')).toHaveAttribute('data-active-ayah', '1:5', { timeout: 30_000 })
  await audioCard.getByRole('button', { name: 'Pause' }).click()
  expect(await audio.evaluate((element: HTMLAudioElement) => element.paused)).toBe(true)
})

test('the translation card steps through the ayahs, and the linguistics card through the words', async ({ page }) => {
  await home(page)
  const translation = card(page, 'translation')
  await translation.scrollIntoViewIfNeeded()
  const well = translation.getByTestId('sample-preview')
  await expect(well).toContainText('1:2', { timeout: 30_000 })
  await translation.getByRole('button', { name: 'Next ayah' }).click()
  await expect(well).toContainText('1:3')

  const linguistics = card(page, 'linguistics')
  await linguistics.scrollIntoViewIfNeeded()
  const words = linguistics.getByRole('button', { name: /^Word / })
  await expect(words.first()).toHaveAttribute('aria-pressed', 'true', { timeout: 30_000 })
  await words.nth(1).click()
  await expect(words.nth(1)).toHaveAttribute('aria-pressed', 'true')
  await expect(words.first()).toHaveAttribute('aria-pressed', 'false')
})

test('each category card links to the catalog filtered to it, with the count the catalog finds', async ({ page }) => {
  const { props } = await home(page)
  const rows = page.getByTestId('library-card')
  await expect(rows).toHaveCount(props.categories.length)
  for (const [index, category] of props.categories.entries()) {
    await expect(rows.nth(index).getByRole('link', { name: category.label, exact: true })).toHaveAttribute(
      'href',
      `/resources?category=${category.key}`,
    )
    await expect(rows.nth(index)).toContainText(category.label)
    await expect(rows.nth(index)).toContainText(category.count.toLocaleString('en'))
  }

  const script = props.categories.find((category) => category.key === 'script')!
  await card(page, 'script').getByRole('link', { name: script.label, exact: true }).click()
  await expect(page).toHaveURL(/\/resources\?category=script$/, { timeout: 30_000 })
  await expect(page.getByRole('button', { name: `Remove ${script.label}` })).toBeVisible()
  // One group, the category, with the row's count as its total.
  const groups = page.getByRole('main').getByRole('heading', { level: 2 })
  await expect(groups).toHaveText([script.label])
  const group = page.getByRole('main').locator('section', { has: page.getByRole('heading', { level: 2 }) })
  await expect(group.locator('h2 + span')).toHaveText(String(script.count))
})

test('the tool cards open their tools, and See all tools opens the overview', async ({ page }) => {
  const { props } = await home(page)
  const tools = page.getByRole('list', { name: 'Contribution tools' }).getByRole('link')
  await expect(tools).toHaveCount(3)
  for (const [index, tool] of props.tools.entries()) {
    await expect(tools.nth(index)).toHaveAttribute('href', tool.href)
    await expect(tools.nth(index)).toContainText(tool.label)
  }
  const first = await page.request.get(props.tools[0].href, { maxRedirects: 0 })
  expect(first.status()).toBeLessThan(500)

  await page.getByRole('link', { name: 'See all tools' }).click()
  await expect(page).toHaveURL(/\/tools$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Contribution tools' })).toBeVisible()
})

test('screenshots of the library and the open source band', async ({ page }, testInfo) => {
  const { props } = await home(page)
  const library = page.locator('section', { has: page.getByTestId('library-card') })
  for (const sample of props.samples) {
    await card(page, sample.category).scrollIntoViewIfNeeded()
    await expect(card(page, sample.category).getByTestId('sample-preview')).toBeVisible({ timeout: 30_000 })
  }
  const shot = (name: string) => `tmp/playwright/home-library/${name}-${testInfo.project.name}.png`
  await library.screenshot({ path: shot('library') })
  await testInfo.attach('library', { path: shot('library'), contentType: 'image/png' })

  const band = page.locator('section', { has: page.getByRole('list', { name: 'Contribution tools' }) })
  await band.screenshot({ path: shot('open-source') })
  await testInfo.attach('open-source', { path: shot('open-source'), contentType: 'image/png' })
})

import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

// The home page's library section and contribution tools (story 002-12) on the development
// clone: a tab per sample of the data, each preview loaded when its tab opens, the category rows
// and the tool cards.

type Props = {
  samples: { type: string; toParam: string; name: string }[]
  categories: { key: string; label: string; count: number }[]
  tools: { label: string; href: string }[]
}

const PREVIEW_PROPS: Record<string, string> = {
  recitation: 'recitationPreview',
  'mushaf-layout': 'mushafLayoutPreview',
  translation: 'translationPreview',
  morphology: 'morphologyPreview',
}
const PREVIEW_TEST_IDS: Record<string, string> = {
  recitation: 'recitation-preview',
  'mushaf-layout': 'mushaf-preview',
  translation: 'text-preview',
  morphology: 'records-preview',
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

// Previews load once the open tab comes near the screen.
const showcase = (page: Page) => page.getByRole('tablist').scrollIntoViewIfNeeded()

const panel = (page: Page) => page.getByRole('tabpanel')
const audio = (page: Page) => panel(page).getByTestId('player').locator('audio')

test('each tab loads and shows the preview of its sample, and only that one', async ({ page }) => {
  const partials: string[] = []
  page.on('request', (request) => {
    const only = request.headers()['x-inertia-partial-data']
    if (only) partials.push(only)
  })
  const { html, props } = await home(page)
  expect(props.samples.map((sample) => sample.type)).toEqual(Object.keys(PREVIEW_PROPS))
  // The first response holds no preview, not even the open tab's.
  for (const prop of Object.values(PREVIEW_PROPS)) expect(html).not.toContain(`"${prop}"`)
  // Nor does the page ask for one while the showcase is off screen.
  await page.waitForLoadState('networkidle')
  expect(partials).toEqual([])

  for (const [index, sample] of props.samples.entries()) {
    const tab = page.getByRole('tab').nth(index)
    await tab.click()
    await expect(tab).toHaveAttribute('aria-selected', 'true')
    await expect(panel(page).getByTestId(PREVIEW_TEST_IDS[sample.type])).toBeVisible({ timeout: 30_000 })
    await expect(panel(page).getByRole('link', { name: sample.name, exact: true })).toHaveAttribute(
      'href',
      `/resources/${sample.type}/${sample.toParam}`,
    )
  }
  expect(partials).toEqual(Object.values(PREVIEW_PROPS))

  // An opened tab keeps its preview: going back asks for nothing.
  await page.getByRole('tab').first().click()
  await expect(panel(page).getByTestId('recitation-preview')).toBeVisible()
  expect(partials).toHaveLength(4)
})

test('the recitation tab plays and pauses, and switching tabs stops it', async ({ page }) => {
  await home(page)
  await showcase(page)
  const player = panel(page).getByTestId('player')
  await expect(player).toBeVisible({ timeout: 30_000 })

  await player.getByRole('button', { name: 'Play', exact: true }).click()
  await expect
    .poll(() => audio(page).evaluate((element: HTMLAudioElement) => element.currentTime), { timeout: 30_000 })
    .toBeGreaterThan(0)
  await player.getByRole('button', { name: 'Pause' }).click()
  expect(await audio(page).evaluate((element: HTMLAudioElement) => element.paused)).toBe(true)

  await player.getByRole('button', { name: 'Play', exact: true }).click()
  await expect(player.getByRole('button', { name: 'Pause' })).toBeVisible()
  const element = await audio(page).elementHandle()
  expect(await element!.evaluate((node: HTMLAudioElement) => node.paused)).toBe(false)

  await page.getByRole('tab', { name: 'Mushaf layouts' }).click()
  await expect(panel(page).getByTestId('player')).toHaveCount(0)
  // The element left the page with its tab, and stopped.
  expect(await element!.evaluate((node: HTMLAudioElement) => [node.isConnected, node.paused])).toEqual([false, true])
  await page.waitForTimeout(1000)
  const at = await element!.evaluate((node: HTMLAudioElement) => node.currentTime)
  await page.waitForTimeout(1000)
  expect(await element!.evaluate((node: HTMLAudioElement) => node.currentTime)).toBe(at)
})

test('each category row links to the catalog filtered to it, with the count the catalog finds', async ({ page }) => {
  const { props } = await home(page)
  const rows = page.locator('a[href^="/resources?category="]')
  await expect(rows).toHaveCount(props.categories.length)
  for (const [index, category] of props.categories.entries()) {
    await expect(rows.nth(index)).toHaveAttribute('href', `/resources?category=${category.key}`)
    await expect(rows.nth(index)).toContainText(category.label)
    await expect(rows.nth(index)).toContainText(category.count.toLocaleString('en'))
  }

  const script = props.categories.find((category) => category.key === 'script')!
  await page.locator('a[href="/resources?category=script"]').click()
  await expect(page).toHaveURL(/\/resources\?category=script$/)
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
  await home(page)
  await showcase(page)
  await expect(panel(page).getByTestId('recitation-preview')).toBeVisible({ timeout: 30_000 })
  const library = page.locator('section', { has: page.getByRole('tablist') })
  const shot = (name: string) => `tmp/playwright/home-library/${name}-${testInfo.project.name}.png`
  await library.screenshot({ path: shot('library') })
  await testInfo.attach('library', { path: shot('library'), contentType: 'image/png' })

  await page.getByRole('tab', { name: 'Morphology' }).click()
  await expect(panel(page).getByTestId('records-preview')).toBeVisible({ timeout: 30_000 })
  await panel(page).screenshot({ path: shot('morphology') })
  await testInfo.attach('morphology', { path: shot('morphology'), contentType: 'image/png' })

  const band = page.locator('section', { has: page.getByRole('list', { name: 'Contribution tools' }) })
  await band.screenshot({ path: shot('open-source') })
  await testInfo.attach('open-source', { path: shot('open-source'), contentType: 'image/png' })
})

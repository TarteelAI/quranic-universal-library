import type { Page, Request } from '@playwright/test'

import { expect, test } from './support/test'

const REQUEST_FORM = 'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=resource_request.yml'
const SEARCH_PROPS = 'filters,results,facets,total,page,pages'

// React has taken over the server-rendered page, so its handlers respond.
async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// Marks the current document; a full page load drops the mark, an Inertia visit keeps it.
async function markDocument(page: Page) {
  await page.evaluate(() => Object.assign(window, { sameDocument: true }))
}

const sameDocument = (page: Page) => page.evaluate(() => 'sameDocument' in window)

const resultCount = async (page: Page) =>
  Number(await page.getByRole('heading', { level: 1 }).locator('span').textContent())

const horizontalOverflow = (page: Page) => page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)

// The filter controls: the rail on desktop, the bottom drawer (opened first) on phones.
async function filterControls(page: Page, isPhone: boolean) {
  if (!isPhone) return page.getByRole('complementary', { name: 'Filters' })
  await page.getByRole('button', { name: /^Filters/ }).click()
  return page.getByRole('dialog', { name: 'Filters' })
}

const isCatalogVisit = (request: Request) =>
  new URL(request.url()).pathname === '/resources' && request.headers()['x-inertia'] === 'true'

test.describe('catalog search', () => {
  test('a URL with a query, two script families, a format and a sort renders that view', async ({ page }, testInfo) => {
    const isPhone = testInfo.project.name === 'phone'
    await page.goto('/resources?q=quran&script[]=madani&script[]=indopak&format=json&sort=name')
    await expect(page.locator('#app[data-server-rendered="true"]')).toHaveCount(1)
    await hydrated(page)

    await expect(page.getByRole('searchbox', { name: 'Search resources' })).toHaveValue('quran')
    await expect(page.getByRole('combobox', { name: 'Sort' })).toHaveValue('name')
    const chips = page.getByRole('group', { name: 'Active filters' }).getByRole('button', { name: /^Remove/ })
    expect(await chips.evaluateAll((buttons) => buttons.map((button) => button.getAttribute('aria-label')))).toEqual([
      'Remove “quran”',
      'Remove Madani',
      'Remove IndoPak',
      'Remove JSON',
    ])
    expect(await page.getByRole('list', { name: 'Resources' }).getByRole('article').count()).toBeGreaterThan(0)
    const controls = await filterControls(page, isPhone)
    for (const name of [/^Madani/, /^IndoPak/, /^JSON/])
      await expect(controls.getByRole('checkbox', { name })).toHaveAttribute('aria-checked', 'true')
  })

  test('a filter change is a partial Inertia reload that updates the URL and the results', async ({
    page,
  }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'the rail is the desktop layout; the drawer has its own test')
    await page.goto('/resources')
    await hydrated(page)
    const before = await resultCount(page)
    await markDocument(page)

    const visit = page.waitForRequest(isCatalogVisit)
    await page
      .getByRole('complementary', { name: 'Filters' })
      .getByRole('checkbox', { name: /^Tafsir/ })
      .click()
    const request = await visit

    expect(new URL(request.url()).search).toBe('?type=tafsir')
    expect(request.headers()['x-inertia-partial-component']).toBe('catalog/CatalogPage')
    expect(request.headers()['x-inertia-partial-data']).toBe(SEARCH_PROPS)
    const props = Object.keys((await (await request.response())!.json()).props)
    expect(props).toEqual(expect.arrayContaining(SEARCH_PROPS.split(',')))
    expect(props).not.toContain('vocabularies')
    expect(props).not.toContain('nav')

    await expect(page).toHaveURL(/\/resources\?type=tafsir$/)
    await expect.poll(() => resultCount(page)).toBeLessThan(before)
    const facts = await page.getByRole('list', { name: 'Resources' }).locator('article h3 + p').allTextContents()
    expect(facts.every((fact) => fact.startsWith('Tafsir'))).toBe(true)
    expect(await sameDocument(page)).toBe(true)
  })

  test('Back and Forward restore the earlier filter states', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'desktop rail')
    await page.goto('/resources')
    await hydrated(page)
    const rail = page.getByRole('complementary', { name: 'Filters' })
    const tafsir = rail.getByRole('checkbox', { name: /^Tafsir/ })
    const sqlite = rail.getByRole('checkbox', { name: /^SQLite/ })

    await tafsir.click()
    await expect(page).toHaveURL(/\?type=tafsir$/)
    await sqlite.click()
    await expect(page).toHaveURL(/\?type=tafsir&format=sqlite$/)
    const both = await resultCount(page)

    await page.goBack()
    await expect(page).toHaveURL(/\?type=tafsir$/)
    await expect(tafsir).toHaveAttribute('aria-checked', 'true')
    await expect(sqlite).toHaveAttribute('aria-checked', 'false')

    await page.goBack()
    await expect(page).toHaveURL(/\/resources$/)
    await expect(tafsir).toHaveAttribute('aria-checked', 'false')
    await expect(page.getByRole('group', { name: 'Active filters' })).toHaveCount(0)

    await page.goForward()
    await page.goForward()
    await expect(page).toHaveURL(/\?type=tafsir&format=sqlite$/)
    await expect(sqlite).toHaveAttribute('aria-checked', 'true')
    expect(await resultCount(page)).toBe(both)
  })

  test('typing a native language name in Arabic script finds that language', async ({ page }) => {
    await page.goto('/resources')
    await hydrated(page)
    await markDocument(page)

    await page.getByRole('searchbox', { name: 'Search resources' }).fill('اردو')
    await expect(page).toHaveURL(/\?q=%D8%A7%D8%B1%D8%AF%D9%88$/)
    await expect.poll(() => resultCount(page)).toBeLessThan(50)
    const facts = await page.getByRole('list', { name: 'Resources' }).locator('article h3 + p').allTextContents()
    expect(facts.length).toBeGreaterThan(0)
    expect(facts.every((fact) => fact.includes('Urdu'))).toBe(true)
    expect(await sameDocument(page)).toBe(true)
  })

  test('at 390 px the filters are a bottom drawer that opens, applies and closes', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'phone', 'phone layout')
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/resources')
    await hydrated(page)
    expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0)
    await expect(page.getByRole('complementary', { name: 'Filters' })).toBeHidden()

    const drawer = await filterControls(page, true)
    await expect(drawer).toBeVisible()
    const bottom = async () => {
      const box = await drawer.boundingBox()
      return Math.round(box!.y + box!.height)
    }
    await expect.poll(bottom).toBe(844)

    await drawer.getByRole('checkbox', { name: /^Tafsir/ }).click()
    await expect(page).toHaveURL(/\?type=tafsir$/)
    await expect(drawer.getByRole('checkbox', { name: /^Tafsir/ })).toHaveAttribute('aria-checked', 'true')
    const show = drawer.getByRole('button', { name: /^Show \d+ results?$/ })
    const count = Number((await show.textContent())!.match(/\d+/)![0])
    await show.click()

    await expect(drawer).toBeHidden()
    expect(await resultCount(page)).toBe(count)
    await expect(page.getByRole('button', { name: 'Remove Tafsir' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Filters · 1' })).toBeVisible()
    expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0)
  })

  test('a filter combination with no results shows the empty state and the request card', async ({ page, context }) => {
    await page.goto('/resources?type=font&language=ur')
    await hydrated(page)

    expect(await resultCount(page)).toBe(0)
    await expect(page.getByText('Nothing matches this search')).toBeVisible()
    const request = page.getByRole('link', { name: 'Request a resource' })
    await expect(request).toHaveAttribute('href', REQUEST_FORM)

    // The new tab asks GitHub for the form (GitHub may then send a signed-out visitor to sign in).
    const opened = context.waitForEvent('page')
    const asked = context.waitForEvent('request', (r) => r.url() === REQUEST_FORM)
    await request.click()
    expect((await opened) === page).toBe(false)
    expect((await asked).isNavigationRequest()).toBe(true)
  })
})

test.describe('spotlight', () => {
  const spotlight = (page: Page) => page.getByRole('dialog', { name: 'Search QUL' })
  const options = (page: Page) => spotlight(page).getByRole('option')
  const spotlightField = (page: Page) => spotlight(page).getByRole('combobox', { name: 'Search QUL' })

  test('opens on the most popular resources and the quick links, and groups pages and tools', async ({ page }) => {
    await page.goto('/resources')
    await hydrated(page)

    await page.keyboard.press('ControlOrMeta+k')
    const popular = spotlight(page).getByRole('group', { name: 'Popular resources' })
    await expect(popular.getByRole('option')).toHaveCount(4)
    await expect(spotlight(page).getByRole('group', { name: 'Quick links' })).toContainText('Browse all resources')

    await spotlightField(page).fill('tajweed')
    await expect(spotlight(page).getByRole('group', { name: 'Tools' }).getByRole('option').first()).toBeVisible()
    await spotlightField(page).fill('tafsir')
    await expect(spotlight(page).getByRole('group', { name: 'Pages' })).toContainText('Tafsirs')
  })

  test('a resource result is an Inertia visit', async ({ page }) => {
    await page.goto('/resources')
    await hydrated(page)
    await markDocument(page)

    await page.keyboard.press('ControlOrMeta+k')
    await spotlightField(page).fill('ibn kathir')
    await expect(options(page).first()).toContainText(/kathir/i)
    await page.keyboard.press('Enter')

    await expect(page).toHaveURL(/\/resources\/tafsir\/[^/?]+$/)
    expect(await sameDocument(page)).toBe(true)
  })

  for (const path of ['/resources/tafsir', '/resources']) {
    test(`on ${path}: opens with the shortcut and closes with Escape, restoring focus`, async ({ page }) => {
      await page.goto(path)
      await hydrated(page)
      const home = page.getByRole('banner').getByRole('link', { name: 'QUL home' })
      await home.focus()

      await page.keyboard.press('ControlOrMeta+k')
      await expect(spotlight(page)).toBeVisible()
      await expect(spotlightField(page)).toBeFocused()

      await page.keyboard.press('Escape')
      await expect(spotlight(page)).toBeHidden()
      await expect(home).toBeFocused()
    })

    test(`on ${path}: the icon opens it; arrows move, Enter opens the result`, async ({ page }) => {
      await page.goto(path)
      await hydrated(page)
      const trigger = page.getByRole('banner').getByRole('button', { name: 'Search resources' })

      await trigger.click()
      await spotlightField(page).fill('ibn kathir')
      await expect(options(page).last()).toHaveText(/^All \d+ results for “ibn kathir”$/)
      await expect(options(page).first()).toContainText(/kathir/i)
      await expect(options(page).first()).toHaveAttribute('aria-selected', 'true')

      await page.keyboard.press('ArrowDown')
      await expect(options(page).nth(1)).toHaveAttribute('aria-selected', 'true')
      await expect(options(page).first()).toHaveAttribute('aria-selected', 'false')
      await page.keyboard.press('ArrowUp')
      await page.keyboard.press('ArrowUp')
      await expect(options(page).last()).toHaveAttribute('aria-selected', 'true')
      await page.keyboard.press('ArrowDown')
      await expect(options(page).first()).toHaveAttribute('aria-selected', 'true')

      await page.keyboard.press('Escape')
      await expect(spotlight(page)).toBeHidden()
      await expect(trigger).toBeFocused()

      await trigger.click()
      await spotlightField(page).fill('ibn kathir')
      await expect(options(page).last()).toHaveText(/^All \d+ results for “ibn kathir”$/)
      await page.keyboard.press('Enter')
      await expect(page).toHaveURL(/\/resources\/tafsir\/[^/?]+$/)
    })
  }

  test('Enter on the last option opens the catalog with every result', async ({ page }) => {
    await page.goto('/resources/tafsir')
    await hydrated(page)
    await markDocument(page)

    await page.keyboard.press('ControlOrMeta+k')
    await spotlightField(page).fill('urdu')
    await expect(options(page).last()).toHaveText(/^All \d+ results for “urdu”$/)
    await page.keyboard.press('ArrowUp')
    await page.keyboard.press('Enter')

    await expect(page).toHaveURL(/\/resources\?q=urdu$/)
    await expect(page.getByRole('searchbox', { name: 'Search resources' })).toHaveValue('urdu')
    await expect(spotlight(page)).toBeHidden()
    expect(await sameDocument(page)).toBe(true)
  })

  test('fast typing sends one request per pause and never shows an older query', async ({ page, stubs }) => {
    const queries: string[] = []
    // The answer for "tafsir" is slow, so it would arrive after the answer for the longer query.
    await stubs.route(/\/spotlight\?/, async (route) => {
      const q = new URL(route.request().url()).searchParams.get('q')!
      queries.push(q)
      if (q === 'tafsir') await new Promise((resolve) => setTimeout(resolve, 1500))
      await route.continue().catch(() => {})
    })
    await page.goto('/resources/translation')
    await hydrated(page)
    await page.keyboard.press('ControlOrMeta+k')

    await spotlightField(page).pressSequentially('tafsir', { delay: 40 })
    await expect.poll(() => queries).toEqual(['tafsir'])
    await spotlightField(page).pressSequentially(' ibn', { delay: 40 })
    await expect(options(page).last()).toHaveText(/^All \d+ results for “tafsir ibn”$/)
    expect(queries).toEqual(['tafsir', 'tafsir ibn'])

    await page.waitForTimeout(2000)
    await expect(options(page).last()).toHaveText(/^All \d+ results for “tafsir ibn”$/)
    expect(queries).toEqual(['tafsir', 'tafsir ibn'])
  })
})

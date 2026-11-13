import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const TUTORIAL = '/docs/tutorial-recitation-end-to-end'

// The side navigation: beside the page on desktop, in a sheet behind the bar on phones.
async function sideNav(page: Page, isPhone: boolean) {
  if (!isPhone) return page.getByRole('complementary').getByRole('navigation', { name: 'Docs' })
  await page.getByRole('button', { name: 'Open the docs menu' }).click()
  return page.getByRole('dialog', { name: 'Docs' }).getByRole('navigation', { name: 'Docs' })
}

test.describe('docs layout', () => {
  test('the side navigation marks the current page and visits another in the app', async ({ page }, testInfo) => {
    const isPhone = testInfo.project.name === 'phone'
    await page.goto(TUTORIAL)
    await hydrated(page)

    const nav = await sideNav(page, isPhone)
    await expect(nav.locator('a[aria-current="page"]')).toHaveText('Recitation')
    await expect(nav.getByText('Coming soon')).toBeVisible()

    await nav.getByRole('link', { name: 'Data Model' }).click()
    await expect(page).toHaveURL(/\/docs\/data-model$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Data Model')
    // An Inertia visit: the phone sheet closed, and the page was not loaded again.
    await expect(page.getByRole('dialog')).toHaveCount(0)
    expect(await page.evaluate(() => performance.getEntriesByType('navigation').length)).toBe(1)
    expect(
      await page.evaluate(() => (performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming).name),
    ).toContain(TUTORIAL)
    await expect((await sideNav(page, isPhone)).locator('a[aria-current="page"]')).toHaveText('Data Model')
  })

  test('the contents list follows the headings', async ({ page }, testInfo) => {
    const isPhone = testInfo.project.name === 'phone'
    await page.goto('/docs/data-model')
    await hydrated(page)

    const article = page.getByRole('article')
    const headings = await article
      .locator('h2, h3')
      .evaluateAll((nodes) => nodes.map((node) => ({ id: node.id, text: node.textContent?.trim() })))
    expect(headings.length).toBeGreaterThan(2)
    if (isPhone) await page.locator('summary', { hasText: 'On this page' }).click()
    const contents = page.getByRole('navigation', { name: 'On this page' }).filter({ visible: true })
    const links = contents.getByRole('link')
    await expect(links).toHaveText(headings.map((heading) => heading.text!))
    await expect(contents.locator('a[aria-current="location"]')).toHaveText(headings[0].text!)

    const target = headings[2]
    await contents.getByRole('link', { name: target.text, exact: true }).click()
    await expect(page).toHaveURL(new RegExp(`#${target.id}$`))
    const top = await page.locator(`#${target.id}`).evaluate((node) => node.getBoundingClientRect().top)
    expect(top).toBeGreaterThanOrEqual(0)
    expect(top).toBeLessThan(200)
    if (!isPhone) await expect(contents.locator('a[aria-current="location"]')).toHaveText(target.text!)
  })

  test('previous and next lead to the neighbouring pages in manifest order', async ({ page }) => {
    await page.goto(TUTORIAL)
    await hydrated(page)

    const pages = page.getByRole('navigation', { name: 'Previous and next pages' })
    await pages.getByRole('link', { name: /Next/ }).click()
    await expect(page).toHaveURL(/\/docs\/tutorial-mushaf-layout-end-to-end$/)
    await pages.getByRole('link', { name: /Previous/ }).click()
    await expect(page).toHaveURL(new RegExp(`${TUTORIAL}$`))
    await pages.getByRole('link', { name: /Previous/ }).click()
    await expect(page).toHaveURL(/\/docs\/tutorials$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Tutorials')
  })

  test('the docs index lists the categories and opens their pages', async ({ page }) => {
    await page.goto('/docs')
    await hydrated(page)

    await expect(page.getByRole('heading', { level: 1 })).toHaveText('QUL documentation')
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { level: 2 })).toHaveText([
      'Download Resources',
      'Contribute Code',
      'Contribute Data',
      /API/,
    ])
    await main
      .getByRole('listitem')
      .filter({ hasText: 'Contribute Code' })
      .getByRole('link', { name: 'Project Setup' })
      .click()
    await expect(page).toHaveURL(/\/docs\/project-setup$/)
  })

  test('the page fits the phone width', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'phone', 'phone layout')
    for (const path of [TUTORIAL, '/docs', '/docs/api']) {
      await page.goto(path)
      await hydrated(page)
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
      expect(overflow, path).toBeLessThanOrEqual(0)
    }
  })
})

test.describe('docs pages', () => {
  test("the tutorial's example runs in its sandboxed frame, and again with edited code", async ({ page }) => {
    await page.goto(TUTORIAL)

    const output = page.frameLocator('iframe[title="Example output"]')
    await expect(output.getByRole('heading', { name: 'Word Playback Preview (Real Arabic Text)' })).toBeVisible()
    await expect(output.locator('#word-list li')).toHaveCount(4)
    // The example highlights one word at a time, in bold.
    await expect(output.locator('#word-list li[style*="font-weight: 700"]')).toHaveCount(1)

    await hydrated(page)
    const editor = page.getByLabel('Example code')
    await editor.fill('document.getElementById("app").textContent = "Edited " + (1 + 1)')
    await page.getByRole('button', { name: 'Run' }).click()
    await expect(output.locator('#app')).toHaveText('Edited 2')

    // Scripts run, but the frame cannot reach this page.
    await editor.fill(
      'const app = document.getElementById("app"); try { app.textContent = parent.document.title } catch (e) { app.textContent = "blocked" }',
    )
    await page.getByRole('button', { name: 'Run' }).click()
    await expect(output.locator('#app')).toHaveText('blocked')

    await page.getByRole('button', { name: 'Reset' }).click()
    await expect(output.locator('#word-list li')).toHaveCount(4)
  })

  test('the copy button copies a code block', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    await page.goto(TUTORIAL)
    await hydrated(page)

    const block = page
      .locator('figure')
      .filter({ has: page.locator('pre') })
      .first()
    const code = await block.locator('pre').innerText()
    await block.getByRole('button', { name: 'Copy code' }).click()

    await expect(block.getByRole('button', { name: 'Copied' })).toBeVisible()
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(code)
  })
})

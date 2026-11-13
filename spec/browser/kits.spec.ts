import type { Page } from '@playwright/test'

import { expect as baseExpect, test } from './support/test'

// The kit page runs a catalog search; allow for a slow server.
const expect = baseExpect.configure({ timeout: 20_000 })

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// No element of `selector` reaches past the right edge of the screen.
async function fitsScreen(page: Page, selector: string) {
  const rights = await page.locator(selector).evaluateAll((all) => all.map((el) => el.getBoundingClientRect().right))
  expect(rights.length).toBeGreaterThan(0)
  expect(Math.max(...rights)).toBeLessThanOrEqual(page.viewportSize()!.width)
}

const main = (page: Page) => page.getByRole('main')

test.describe('starter kits and the ways into the guided setup (002-16)', () => {
  test('home: a goal card opens the setup with the goal answered', async ({ page }) => {
    await page.goto('/')
    await hydrated(page)

    await main(page).getByRole('link', { name: /^Audio and recitation/ }).click()
    await expect(page).toHaveURL(/\/start\?goal=audio$/)
    await expect(page.getByRole('heading', { name: 'Where will it run?' })).toBeVisible()
    await page.getByRole('button', { name: 'Goal' }).click()
    await expect(page.getByRole('button', { name: /^Audio and recitation/ })).toHaveAttribute('aria-pressed', 'true')
  })

  test('home: the hero and closing buttons open the setup, and the kit row leads to the kits', async ({ page }) => {
    await page.goto('/')
    await hydrated(page)

    const starts = main(page).getByRole('link', { name: 'Start building' })
    await expect(starts).toHaveCount(2)
    await starts.last().click()
    await expect(page).toHaveURL(/\/start$/)
    await expect(page.getByRole('heading', { name: 'What are you building?' })).toBeVisible()

    await page.goBack()
    await main(page).getByRole('link', { name: 'Start building' }).first().click()
    await expect(page).toHaveURL(/\/start$/)

    await page.goto('/')
    await hydrated(page)
    await fitsScreen(page, 'main section a[href^="/kits/"]')
    await main(page).getByRole('link', { name: /Madani reader/ }).click()
    await expect(page).toHaveURL(/\/kits\/madani-reader$/)
    await expect(page.getByRole('heading', { level: 1, name: 'Madani reader' })).toBeVisible()

    await page.goBack()
    await main(page).getByRole('link', { name: 'All kits' }).click()
    await expect(page).toHaveURL(/\/kits$/)
    await expect(page.getByRole('heading', { level: 1, name: /^Starter kits/ })).toBeVisible()
    await fitsScreen(page, 'main a[href^="/kits/"]')
  })

  test('header: the Start building menu links the goals and the kits', async ({ page }, testInfo) => {
    await page.goto('/resources/translation')
    await hydrated(page)

    if (testInfo.project.name === 'phone') {
      await page.getByRole('banner').getByRole('button', { name: 'Menu' }).click()
      const sheet = page.getByRole('dialog', { name: 'Menu' })
      await sheet.getByRole('button', { name: /^Start building\b/ }).click()
      const section = sheet.getByRole('region', { name: /^Start building\b/ })
      await expect(section.getByRole('link', { name: /^Research, NLP and AI/ })).toHaveAttribute(
        'href',
        '/start?goal=research',
      )
      await section.getByRole('link', { name: /^Starter kits/ }).click()
    } else {
      const nav = page.getByRole('navigation', { name: 'Main' })
      await nav.getByRole('button', { name: 'Start building' }).focus()
      await page.keyboard.press('Enter')
      await expect(nav.getByRole('link', { name: /^Research, NLP and AI/ })).toHaveAttribute(
        'href',
        '/start?goal=research',
      )
      await testInfo.attach('start-building-menu', { body: await page.screenshot(), contentType: 'image/png' })
      await nav.getByRole('link', { name: /^Starter kits/ }).click()
    }
    await expect(page).toHaveURL(/\/kits$/)
    await expect(page.getByRole('heading', { level: 1, name: /^Starter kits/ })).toBeVisible()
  })

  test('kit page: each item with its card, reason and alternative; the answers reopen the setup', async ({
    page,
  }, testInfo) => {
    await page.goto('/kits/indopak-urdu')
    await hydrated(page)

    const items = page.getByRole('list', { name: 'In IndoPak reader with Urdu and English' }).getByRole('listitem')
    await expect(items).toHaveCount(7)
    await expect(items.first()).toContainText('Page layout')
    await expect(items.first()).toContainText('Why: ')
    await fitsScreen(page, 'main article')
    await testInfo.attach('kit-page', { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' })

    const swap = items.first().getByRole('link', { name: /^Swap for / })
    const alternative = await swap.getAttribute('href')
    expect(alternative).toMatch(/^\/resources\/mushaf-layout\//)
    await swap.click()
    await expect(page).toHaveURL(new RegExp(`${alternative}$`))

    await page.goBack()
    const card = items.first().getByRole('article')
    const detail = await card.getByRole('link').getAttribute('href')
    await card.getByRole('link').click()
    await expect(page).toHaveURL(new RegExp(`${detail}$`))

    await page.goBack()
    await page.getByRole('link', { name: 'build your own from these answers' }).click()
    await expect(page).toHaveURL(/\/start\?goal=reader&/)
    await expect(page.getByRole('heading', { name: 'Which languages?' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Urdu' })).toHaveAttribute('aria-pressed', 'true')
  })
})

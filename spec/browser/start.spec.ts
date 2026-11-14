import type { Page } from '@playwright/test'

import { expect as baseExpect, test } from './support/test'

// The results run a catalog search for each need; allow for a slow server.
const expect = baseExpect.configure({ timeout: 20_000 })

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// Each goal with a platform; every setup reads Madani and English.
const SETUPS = [
  { goal: 'reader', label: 'Quran reader app', platform: 'Android', banner: 'Quran reader app' },
  { goal: 'audio', label: 'Audio and recitation', platform: 'iOS', banner: 'Audio and recitation app' },
  { goal: 'study', label: 'Translation and tafsir', platform: 'Web', banner: 'Translation and tafsir app' },
  { goal: 'learning', label: 'Learning and word by word', platform: 'Web', banner: 'Learning and word by word app' },
  {
    goal: 'research',
    label: 'Research, NLP and AI',
    platform: 'Data or ML pipeline',
    banner: 'Research, NLP and AI app',
  },
  {
    goal: 'print',
    label: 'Print, images and video',
    platform: 'Print and video',
    banner: 'Print, images and video app',
  },
]

const continueButton = (page: Page) => page.getByRole('button', { name: 'Continue' })
const needs = (page: Page) =>
  page.getByRole('navigation', { name: 'Your app needs' }).getByRole('link').allTextContents()
const cardNames = (page: Page) => page.locator('main article h3').allTextContents()

test.describe('guided setup (002-15)', () => {
  for (const setup of SETUPS) {
    test(`${setup.goal}: the steps end on the filtered catalog, the URL reopens it, and edit keeps the answers`, async ({
      page,
      browser,
    }) => {
      await page.goto('/start')
      await hydrated(page)

      await expect(page.getByRole('heading', { name: 'What are you building?' })).toBeVisible()
      await page.getByRole('button', { name: new RegExp(`^${setup.label}`) }).click()
      await continueButton(page).click()
      await expect(page).toHaveURL(new RegExp(`/start\\?goal=${setup.goal}$`))

      await page.getByRole('button', { name: new RegExp(`^${setup.platform}`) }).click()
      await continueButton(page).click()
      await expect(page.getByRole('heading', { name: 'Which features do you need?' })).toBeVisible()
      await continueButton(page).click()

      await page.getByRole('button', { name: /^Madani/ }).click()
      await continueButton(page).click()

      await page.getByRole('searchbox', { name: 'Search languages' }).fill('engl')
      await page.getByRole('group', { name: 'Languages' }).getByRole('button', { name: 'English' }).click()
      await page.getByRole('link', { name: 'Show matching resources' }).click()

      await expect(page).toHaveURL(
        new RegExp(`/resources\\?goal=${setup.goal}&platform=\\w+&feature=[\\w,-]+&script=madani&lang=en$`),
      )
      await expect(page.getByText(`Filtered for your ${setup.banner}`)).toBeVisible()
      await expect(page.getByRole('heading', { name: 'Resources for your app' })).toBeVisible()
      const checklist = await needs(page)
      expect(checklist.length).toBeGreaterThan(0)
      await expect(page.locator('main article').first()).toBeVisible()
      const cards = await cardNames(page)
      expect(cards.length).toBeGreaterThan(0)
      // No card is wider than the screen.
      const rights = await page
        .locator('main article')
        .evaluateAll((all) => all.map((card) => card.getBoundingClientRect().right))
      expect(Math.max(...rights)).toBeLessThanOrEqual(page.viewportSize()!.width)

      // The same URL in a new browser context shows the same result.
      const results = page.url()
      const other = await browser.newContext({
        viewport: page.viewportSize(),
        userAgent: await page.evaluate(() => navigator.userAgent),
      })
      // As the harness does for `page`: GA4's collect requests are answered here.
      await other.route(/google-analytics\.com\/g\/collect/, (route) => route.fulfill({ status: 204 }))
      const shared = await other.newPage()
      await shared.goto(results)
      await expect(shared.getByText(`Filtered for your ${setup.banner}`)).toBeVisible()
      expect(await needs(shared)).toEqual(checklist)
      expect(await cardNames(shared)).toEqual(cards)
      await other.close()

      // Edit returns to the flow at the last step with the answers kept.
      await page.getByRole('link', { name: 'Edit answers' }).click()
      await expect(page).toHaveURL(/\/start\?goal=/)
      await expect(page.getByRole('heading', { name: 'Which languages?' })).toBeVisible()
      await expect(page.getByRole('button', { name: 'English' })).toHaveAttribute('aria-pressed', 'true')
      await page.getByRole('button', { name: 'Goal' }).click()
      await expect(page.getByRole('button', { name: new RegExp(`^${setup.label}`) })).toHaveAttribute(
        'aria-pressed',
        'true',
      )
    })
  }

  test('a partial setup reopens at its first unanswered step', async ({ page }) => {
    await page.goto('/start?goal=reader&platform=ios')
    await hydrated(page)

    await expect(page.getByRole('heading', { name: 'Which features do you need?' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Mushaf pages' })).toHaveAttribute('aria-pressed', 'true')
    await page.reload()
    await expect(page.getByRole('heading', { name: 'Which features do you need?' })).toBeVisible()
  })
})

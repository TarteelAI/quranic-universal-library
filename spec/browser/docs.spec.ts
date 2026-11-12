import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const TUTORIAL = '/docs/tutorial-recitation-end-to-end'

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

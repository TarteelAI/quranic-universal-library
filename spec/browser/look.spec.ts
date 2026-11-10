import { test } from './support/test'

// A look, not a test: `LOOK_PATH=/resources/font yarn test:browser look.spec.ts` saves a
// full-page screenshot of that path at each project's width and prints where it is.
test('look', async ({ page }, testInfo) => {
  const path = process.env.LOOK_PATH
  test.skip(!path, 'Set LOOK_PATH to the path to look at.')

  await page.goto(path!)
  await page.waitForLoadState('networkidle')
  const file = testInfo.outputPath(`look-${testInfo.project.name}.png`)
  await page.screenshot({ path: file, fullPage: true })
  await testInfo.attach('look', { path: file, contentType: 'image/png' })
  console.log(`[look] ${testInfo.project.name}: ${file}`)
})

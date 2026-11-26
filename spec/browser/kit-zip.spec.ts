import { execFileSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'

import type { Page } from '@playwright/test'

import { expect as baseExpect, test } from './support/test'

// "Download kit" (components/qul/zip-download.tsx) on the development clone: a signed-out visitor
// signs in from the kit page and comes back to it, then the page fetches each file of the kit
// through its download URL (the redirect goes to the real CDN, so this needs network access) and
// saves one zip. Chromium writes it to the file the visitor picks; the test stands in for the save
// dialog, and also runs without it, as Safari and Firefox do (a Blob, then a download). Each run
// counts one download per file for the fake account, as clicking each link would.

// The kit page runs a catalog search and the files come from the CDN; allow for both.
const expect = baseExpect.configure({ timeout: 30_000 })

const KIT = '/kits/recitation'
const PASSWORD = 'fake-account-password'

type Lookup = {
  items: { resource: { type: string; toParam: string } | null; restricted: boolean; files: { filename: string }[] }[]
}

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// The zip's entries, as the lookup names the kit's files, plus the README.
async function expectedEntries(page: Page) {
  const ids = await page.evaluate(
    () =>
      JSON.parse(document.querySelector('script[data-page="app"]')?.textContent ?? '{}').props.items.map(
        (item: { resource: { id: number } }) => item.resource.id,
      ) as number[],
  )
  const lookup = (await (await page.context().request.get(`/bundle?ids=${ids.join(',')}`)).json()) as Lookup
  const paths = lookup.items.flatMap(({ resource, restricted, files }) =>
    resource && !restricted ? files.map((file) => `${resource.type}/${resource.toParam}/${file.filename}`) : [],
  )
  expect(paths.length).toBeGreaterThan(1)
  return [...paths, 'README.md'].sort()
}

async function signInFromKit(page: Page, email: string) {
  await page.goto(KIT)
  await hydrated(page)
  await page.getByRole('main').getByRole('link', { name: 'Sign in to download' }).click()
  await page.locator('#user_email').fill(email)
  await page.locator('#user_password').fill(PASSWORD)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(new RegExp(`${KIT}$`))
  await hydrated(page)
}

function entriesOf(path: string) {
  return execFileSync('unzip', ['-Z1', path], { encoding: 'utf8' }).trim().split('\n').sort()
}

function readmeOf(path: string) {
  return execFileSync('unzip', ['-p', path, 'README.md'], { encoding: 'utf8' })
}

test.describe('downloading a starter kit as one zip', () => {
  // Each width signs in as its own fake account (`bin/rails dev:fake_accounts`).
  const account = (name: string) => (name === 'desktop' ? 'reader@example.test' : 'admin@example.test')

  test('Chromium: the zip is written to the picked file, with every file of the kit and a README', async ({
    page,
  }, testInfo) => {
    test.setTimeout(120_000)
    // The save dialog: a writable that keeps the bytes for the test.
    await page.addInitScript(() => {
      const chunks: BlobPart[] = []
      Object.assign(window, {
        __zipChunks: chunks,
        __zipName: null as string | null,
        showSaveFilePicker: async ({ suggestedName }: { suggestedName: string }) => {
          Object.assign(window, { __zipName: suggestedName })
          return {
            createWritable: async () =>
              new WritableStream<Uint8Array>({
                write: (chunk) => void chunks.push(chunk as BlobPart),
                close: () => void Object.assign(window, { __zipDone: true }),
              }),
          }
        },
      })
    })
    await signInFromKit(page, account(testInfo.project.name))
    const expected = await expectedEntries(page)

    await page.getByRole('button', { name: 'Download kit' }).click()
    await expect(page.getByRole('progressbar', { name: 'Zip progress' })).toBeVisible()
    await page.waitForFunction(() => (window as unknown as { __zipDone?: boolean }).__zipDone === true, null, {
      timeout: 90_000,
    })
    await expect(page.getByText('recitation-with-highlighting.zip is downloaded.')).toBeVisible()

    const { name, base64 } = await page.evaluate(async () => {
      const w = window as unknown as { __zipChunks: BlobPart[]; __zipName: string }
      const blob = new Blob(w.__zipChunks)
      const bytes = new Uint8Array(await blob.arrayBuffer())
      let binary = ''
      for (const byte of bytes) binary += String.fromCharCode(byte)
      return { name: w.__zipName, base64: btoa(binary) }
    })
    expect(name).toBe('recitation-with-highlighting.zip')
    const path = testInfo.outputPath(name)
    writeFileSync(path, base64, 'base64')

    expect(entriesOf(path)).toEqual(expected)
    const readme = readmeOf(path)
    expect(readme).toMatch(/^# Recitation with highlighting\n/)
    expect(readme).toContain('/resources/recitation/')
    expect(readme).not.toContain('## Not included')
  })

  test('without a save dialog (Safari, Firefox): the zip downloads as a file', async ({ page }, testInfo) => {
    test.setTimeout(120_000)
    await page.addInitScript(() => {
      delete (window as unknown as { showSaveFilePicker?: unknown }).showSaveFilePicker
      delete (Window.prototype as unknown as { showSaveFilePicker?: unknown }).showSaveFilePicker
    })
    await signInFromKit(page, account(testInfo.project.name))
    expect(await page.evaluate(() => 'showSaveFilePicker' in window)).toBe(false)
    const expected = await expectedEntries(page)

    const download = page.waitForEvent('download', { timeout: 90_000 })
    await page.getByRole('button', { name: 'Download kit' }).click()
    const file = await download
    expect(file.suggestedFilename()).toBe('recitation-with-highlighting.zip')
    const path = testInfo.outputPath(file.suggestedFilename())
    await file.saveAs(path)

    expect(entriesOf(path)).toEqual(expected)
  })
})

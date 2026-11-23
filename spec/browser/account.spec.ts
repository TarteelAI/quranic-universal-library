import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

// Needs the `account` page group on the server (QUL_PAGE_GROUPS in playwright.config.ts).

const READER = { email: 'reader@example.test', password: 'fake-account-password', name: 'Fake' }

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

const notifications = (page: Page) => page.getByRole('region', { name: /^Notifications/ })

test.describe('profile and account settings', () => {
  test('a signed-out visitor is sent to sign-in and comes back to the profile', async ({ page }) => {
    await page.goto('/profile?tab=contributions')
    await expect(page).toHaveURL(/\/users\/sign_in\?user_return_to=%2Fprofile%3Ftab%3Dcontributions$/)

    await page.locator('#user_email').fill(READER.email)
    await page.locator('#user_password').fill(READER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(/\/profile\?tab=contributions$/)
    await expect(page.getByRole('tab', { name: /Contributions/ })).toHaveAttribute('aria-selected', 'true')
    // The notice is a toast over the page: the page's first heading keeps its place.
    await expect(notifications(page).getByText('Signed in successfully.')).toBeVisible()
  })

  test('the account menu opens the profile; a saved setting returns there with a toast', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'the account menu is in the desktop header')
    await page.goto('/users/sign_in?user_return_to=%2Fresources%2Ftranslation')
    await page.locator('#user_email').fill(READER.email)
    await page.locator('#user_password').fill(READER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/resources\/translation$/)
    await hydrated(page)
    await markDocument(page)

    await page
      .getByRole('banner')
      .getByRole('button', { name: `Account menu: ${READER.name}` })
      .click()
    await expect(page.getByRole('menuitem').filter({ visible: true })).toHaveText([
      'Profile',
      'Account settings',
      'Sign out',
    ])
    await page.getByRole('menuitem', { name: 'Profile' }).click()
    await expect(page).toHaveURL(/\/profile$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText(READER.name)
    await expect(page.getByRole('tab', { name: /Downloads/ })).toHaveAttribute('aria-selected', 'true')

    await page.getByRole('tab', { name: /Edit access/ }).click()
    await expect(page).toHaveURL(/\/profile\?tab=resources$/)
    await expect(page.getByRole('tab', { name: /Edit access/ })).toHaveAttribute('aria-selected', 'true')

    await page.getByRole('link', { name: 'Edit profile' }).click()
    await expect(page).toHaveURL(/\/profile\/edit$/)
    await expect(page.getByRole('button', { name: 'Save email and password' })).toBeDisabled()
    await page.getByRole('button', { name: 'Save profile' }).click()

    await expect(page).toHaveURL(/\/profile$/)
    await expect(notifications(page).getByText('Your account has been updated.')).toBeVisible()
    expect(await sameDocument(page)).toBe(true)
  })

  test('a wrong current password shows its error on the field and changes nothing', async ({ page }) => {
    await page.goto('/users/sign_in?user_return_to=%2Fprofile%2Fedit')
    await page.locator('#user_email').fill(READER.email)
    await page.locator('#user_password').fill(READER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/profile\/edit$/)
    await hydrated(page)

    await page.getByLabel('New password', { exact: true }).fill('another-fake-password')
    await page.getByLabel('Confirm new password').fill('another-fake-password')
    await page.getByLabel('Current password').fill('not-the-password')
    await page.getByRole('button', { name: 'Save email and password' }).click()

    await expect(page.getByText('Current password is invalid')).toBeVisible()
    await expect(page).toHaveURL(/\/profile\/edit$/)
    await expect(page.getByLabel('Current password')).toHaveAttribute('aria-invalid', 'true')
  })
})

// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { settingsPageProps } from '@/test/account'
import { renderPageOnServer } from '@/test/inertia'
import { requestsNav, signedInAuth } from '@/test/shell'

import SettingsPage from './SettingsPage'

describe('account/SettingsPage on the server', () => {
  it('renders both forms with their values without browser globals', async () => {
    const { body } = await renderPageOnServer(SettingsPage, {
      props: settingsPageProps,
      shared: { nav: requestsNav, auth: signedInAuth },
      url: '/profile/edit',
    })

    expect(body).toContain('Account settings')
    expect(body).toContain('value="Fake"')
    expect(body).toContain('value="reader@example.test"')
    expect(body).toContain('Verified')
  })
})

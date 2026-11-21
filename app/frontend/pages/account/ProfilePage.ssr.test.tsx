// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { profilePageProps } from '@/test/account'
import { renderPageOnServer } from '@/test/inertia'
import { requestsNav, signedInAuth } from '@/test/shell'

import ProfilePage from './ProfilePage'

describe('account/ProfilePage on the server', () => {
  it('renders the user, the tabs and the open tab without browser globals', async () => {
    const { body } = await renderPageOnServer(ProfilePage, {
      props: profilePageProps,
      shared: { nav: requestsNav, auth: signedInAuth },
      url: '/profile?download_type=translation',
    })

    expect(body).toContain('Fake Reader')
    expect(body).toContain('Building a study app.')
    expect(body).toContain('Saheeh International')
    expect(body).toContain('Update available')
    expect(body).toContain('href="/profile?download_type=tafsir"')
  })
})

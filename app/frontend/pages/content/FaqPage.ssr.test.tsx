// @vitest-environment node
import { describe, expect, it } from 'vitest'

import { faqProps } from '@/test/content'
import { renderPageOnServer } from '@/test/inertia'

import FaqPage from './FaqPage'

describe('content/FaqPage on the server', () => {
  it('renders the questions and answers without browser globals', async () => {
    const { body } = await renderPageOnServer(FaqPage, { props: faqProps, url: '/faq' })

    expect(body).toContain('id="faq-7"')
    expect(body).toContain('<strong>Quran resources</strong>')
  })
})

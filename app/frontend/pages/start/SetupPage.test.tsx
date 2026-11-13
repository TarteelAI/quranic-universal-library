import { router } from '@inertiajs/react'
import { fireEvent, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { renderPage } from '@/test/inertia'
import { setupPageProps } from '@/test/start'

import SetupPage from './SetupPage'

function pressed(name: string) {
  return screen.getByRole('button', { name: new RegExp(name) }).getAttribute('aria-pressed')
}

describe('start/SetupPage', () => {
  afterEach(() => vi.restoreAllMocks())

  it('walks the five steps, keeping the answered steps in the URL', () => {
    const replace = vi.spyOn(router, 'replace').mockImplementation(() => {})
    renderPage(SetupPage, { props: setupPageProps, url: '/start' })

    expect(screen.getByRole('heading', { name: 'What are you building?' })).toBeDefined()
    const next = screen.getByRole('button', { name: /Continue/ })
    expect(next.hasAttribute('disabled')).toBe(true)
    fireEvent.click(screen.getByRole('button', { name: /Quran reader app/ }))
    expect(pressed('Quran reader app')).toBe('true')
    fireEvent.click(next)
    expect(replace).toHaveBeenLastCalledWith(expect.objectContaining({ url: '/start?goal=reader' }))

    expect(screen.getByRole('heading', { name: 'Where will it run?' })).toBeDefined()
    fireEvent.click(screen.getByRole('button', { name: /iOS/ }))
    fireEvent.click(screen.getByRole('button', { name: /Continue/ }))
    expect(replace).toHaveBeenLastCalledWith(expect.objectContaining({ url: '/start?goal=reader&platform=ios' }))

    // The features follow the goal until the step is answered.
    const features = within(screen.getByRole('group', { name: 'Features' }))
    expect(features.getByRole('button', { name: 'Mushaf pages' }).getAttribute('aria-pressed')).toBe('true')
    expect(features.getByRole('button', { name: 'Audio playback' }).getAttribute('aria-pressed')).toBe('false')
    fireEvent.click(features.getByRole('button', { name: 'Mushaf pages' }))
    fireEvent.click(screen.getByRole('button', { name: /Continue/ }))
    expect(replace).toHaveBeenLastCalledWith(
      expect.objectContaining({ url: '/start?goal=reader&platform=ios&feature=translation,nav' }),
    )

    // Several scripts, and Continue waits for one.
    expect(screen.getByRole('button', { name: /Continue/ }).hasAttribute('disabled')).toBe(true)
    fireEvent.click(screen.getByRole('button', { name: /IndoPak/ }))
    fireEvent.click(screen.getByRole('button', { name: /Madani/ }))
    fireEvent.click(screen.getByRole('button', { name: /Continue/ }))

    fireEvent.change(screen.getByRole('searchbox', { name: 'Search languages' }), { target: { value: 'ur' } })
    const languages = within(screen.getByRole('group', { name: 'Languages' }))
    expect(languages.getAllByRole('button').map((chip) => chip.getAttribute('aria-label'))).toEqual(['Urdu'])
    fireEvent.click(languages.getByRole('button', { name: 'Urdu' }))

    const results = screen.getByRole('link', { name: /Show matching resources/ })
    expect(results.getAttribute('href')).toBe(
      '/resources?goal=reader&platform=ios&feature=translation,nav&script=indopak,madani&lang=ur',
    )
  })

  it('opens at the step the server names, with the answers kept, and goes back', () => {
    const replace = vi.spyOn(router, 'replace').mockImplementation(() => {})
    const answers = {
      goals: ['audio'],
      platforms: [],
      features: ['audio'],
      scripts: ['madani'],
      languages: ['en'],
      answered: ['goal', 'platform', 'feature', 'script', 'lang'] as const,
      step: 4,
    }
    const url = '/start?goal=audio&platform=&feature=audio&script=madani&lang=en'
    window.history.replaceState(null, '', url)
    renderPage(SetupPage, {
      props: { ...setupPageProps, answers: { ...answers, answered: [...answers.answered] } },
      url,
    })

    expect(screen.getByRole('heading', { name: 'Which languages?' })).toBeDefined()
    expect(pressed('English')).toBe('true')
    expect(replace).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', { name: 'Features' }))
    expect(screen.getByRole('heading', { name: 'Which features do you need?' })).toBeDefined()
    expect(pressed('Audio playback')).toBe('true')
    expect(pressed('Mushaf pages')).toBe('false')
    fireEvent.click(screen.getByRole('button', { name: /Back/ }))
    expect(screen.getByRole('heading', { name: 'Where will it run?' })).toBeDefined()
    window.history.replaceState(null, '', '/')
  })

  it('ends on the catalog link only while the catalog serves it', () => {
    const answers = { ...setupPageProps.answers, goals: ['reader'], scripts: ['madani'], step: 4 }
    renderPage(SetupPage, { props: { ...setupPageProps, answers, catalogPages: false }, url: '/start' })

    expect(screen.queryByRole('link', { name: /Show matching resources/ })).toBeNull()
    expect(screen.getByRole('link', { name: /Browse resources/ }).getAttribute('href')).toBe('/resources')
  })
})

import { act, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { ayahRecitationPreview, recitationPreview, unsegmentedRecitationPreview } from '@/test/previews'

import type { PreviewNavigation } from './navigation'
import { activeAyah } from './recitation-player'
import { Preview } from './preview'

function navigation(): PreviewNavigation {
  return { navigate: vi.fn(), showView: vi.fn(), loading: false }
}

// jsdom plays nothing. The element's position is a clock the test sets (`at`), and the player
// reads it on each animation frame, which the fake timers run one at a time.
let position = 0

function fakeAudio() {
  position = 0
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(function (this: HTMLMediaElement) {
    this.dispatchEvent(new Event('play'))
    return Promise.resolve()
  })
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(function (this: HTMLMediaElement) {
    this.dispatchEvent(new Event('pause'))
  })
  Object.defineProperty(HTMLMediaElement.prototype, 'currentTime', {
    configurable: true,
    get: () => position / 1000,
    set: (seconds: number) => {
      position = seconds * 1000
    },
  })
}

function audio() {
  return screen.getByTestId('player').querySelector('audio')!
}

function highlighted() {
  return screen.getByTestId('recitation-preview').dataset.activeAyah
}

function at(ms: number) {
  position = ms
  act(() => vi.advanceTimersToNextFrame())
}

describe('activeAyah', () => {
  const { ayahs } = recitationPreview

  it('names the ayah whose segment holds the moment, and none in the pauses between ayahs', () => {
    expect(activeAyah(ayahs, 0, 0)?.key).toBe('1:1')
    expect(activeAyah(ayahs, 0, 4469)?.key).toBe('1:1')
    expect(activeAyah(ayahs, 0, 4470)).toBeNull()
    expect(activeAyah(ayahs, 0, 4670)?.key).toBe('1:2')
    expect(activeAyah(ayahs, 0, 12539)?.key).toBe('1:2')
    expect(activeAyah(ayahs, 0, 55940)?.key).toBe('1:7')
    expect(activeAyah(ayahs, 0, 75389)).toBeNull()
    expect(activeAyah(ayahs, 1, 100)).toBeNull()
  })

  it('names nothing for ayahs without times', () => {
    expect(activeAyah(unsegmentedRecitationPreview.ayahs, 0, 1000)).toBeNull()
  })
})

describe('RecitationPlayer', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['requestAnimationFrame', 'cancelAnimationFrame'] })
    Element.prototype.scrollIntoView = vi.fn()
    fakeAudio()
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('loads no audio until play is pressed', () => {
    render(<Preview preview={recitationPreview} navigation={navigation()} />)

    expect(audio().getAttribute('src')).toBeNull()
    expect(audio().getAttribute('preload')).toBe('none')
    fireEvent.click(screen.getByRole('button', { name: 'Play' }))
    expect(audio().getAttribute('src')).toBe(recitationPreview.tracks[0])
  })

  it('moves the highlight at the segment boundary times while it plays', () => {
    render(<Preview preview={recitationPreview} navigation={navigation()} />)
    expect(highlighted()).toBe('')

    fireEvent.click(screen.getByRole('button', { name: 'Play' }))
    at(4469)
    expect(highlighted()).toBe('1:1')
    expect(
      screen.getByText('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ').closest('li')?.getAttribute('aria-current'),
    ).toBe('true')
    at(4470)
    expect(highlighted()).toBe('')
    at(4670)
    expect(highlighted()).toBe('1:2')
    at(15669)
    expect(highlighted()).toBe('')
    at(15670)
    expect(highlighted()).toBe('1:3')
    expect(screen.getByTestId('position').textContent).toBe('0:15')
  })

  it('plays from an ayah: seeks to its start', () => {
    render(<Preview preview={recitationPreview} navigation={navigation()} />)

    fireEvent.click(screen.getByRole('button', { name: 'Play from ayah 1:5' }))
    act(() => vi.advanceTimersToNextFrame())
    expect(highlighted()).toBe('1:5')
    expect(audio().currentTime).toBe(33.045)
  })

  it('plays a recitation without segments with no highlight, and says why', () => {
    render(<Preview preview={unsegmentedRecitationPreview} navigation={navigation()} />)

    fireEvent.click(screen.getByRole('button', { name: 'Play' }))
    at(5000)
    expect(highlighted()).toBe('')
    expect(screen.queryByRole('button', { name: /Play from ayah/ })).toBeNull()
    expect(screen.getByText(/has no segment data for this surah/)).toBeDefined()
    expect(screen.getByRole('button', { name: 'Pause' })).toBeDefined()
  })

  it('plays an ayah-by-ayah recitation file after file, highlighting the playing ayah', () => {
    render(<Preview preview={ayahRecitationPreview} navigation={navigation()} />)

    fireEvent.click(screen.getByRole('button', { name: 'Play' }))
    at(1000)
    expect(highlighted()).toBe('1:1')
    fireEvent(audio(), new Event('ended'))
    expect(audio().getAttribute('src')).toBe(ayahRecitationPreview.tracks[1])
    at(1500)
    expect(highlighted()).toBe('1:2')
  })

  it('changes the surah through the navigation', () => {
    const nav = navigation()
    render(<Preview preview={recitationPreview} navigation={nav} />)

    fireEvent.change(screen.getByRole('combobox', { name: 'Surah' }), { target: { value: '114' } })
    expect(nav.navigate).toHaveBeenCalledWith({ surah: 114 })
  })
})

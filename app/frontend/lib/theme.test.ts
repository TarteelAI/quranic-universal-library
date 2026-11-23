import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { chooseTheme, followSystemTheme } from './theme'

// A stand-in for the operating-system setting that a test can change.
function fakeSystem(dark: boolean) {
  const listeners: ((event: { matches: boolean }) => void)[] = []
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => ({
      get matches() {
        return dark
      },
      addEventListener: (_: string, listener: (event: { matches: boolean }) => void) => listeners.push(listener),
    })),
  )
  return (value: boolean) => {
    dark = value
    listeners.forEach((listener) => listener({ matches: value }))
  }
}

const isDark = () => document.documentElement.classList.contains('dark')

describe('theme', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.classList.remove('dark')
  })
  afterEach(() => vi.unstubAllGlobals())

  it('follows the system setting live while nothing is stored', () => {
    const setSystemDark = fakeSystem(false)
    followSystemTheme()

    setSystemDark(true)
    expect(isDark()).toBe(true)
    setSystemDark(false)
    expect(isDark()).toBe(false)
  })

  it('keeps a stored light or dark choice when the system setting changes', () => {
    const setSystemDark = fakeSystem(false)
    followSystemTheme()

    chooseTheme('light')
    setSystemDark(true)
    expect(isDark()).toBe(false)
    expect(localStorage.getItem('qul-theme')).toBe('light')

    chooseTheme('dark')
    setSystemDark(false)
    expect(isDark()).toBe(true)
  })

  it('stores system, applies the system setting at once and follows it after that', () => {
    const setSystemDark = fakeSystem(true)
    followSystemTheme()
    chooseTheme('light')

    chooseTheme('system')
    expect(localStorage.getItem('qul-theme')).toBe('system')
    expect(isDark()).toBe(true)
    setSystemDark(false)
    expect(isDark()).toBe(false)
  })
})

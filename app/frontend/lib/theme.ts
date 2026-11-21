import { useSyncExternalStore } from 'react'

export type Theme = 'light' | 'dark'
/** What the visitor chose; `system` follows the operating-system setting. */
export type ThemePreference = Theme | 'system'

// The stored choice. The inline script in app/views/layouts/inertia.html.erb reads the same key
// before the first paint, so the page never flashes the wrong theme: a stored light or dark
// wins, otherwise (nothing stored, or `system`) the system setting decides.
const STORAGE_KEY = 'qul-theme'
const SYSTEM_DARK = '(prefers-color-scheme: dark)'

function storedPreference(): ThemePreference {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY)
    return value === 'light' || value === 'dark' ? value : 'system'
  } catch {
    return 'system'
  }
}

// Storage can be blocked; the choice then lasts until the next full page load.
let unsavedPreference: ThemePreference | null = null
const currentPreference = () => unsavedPreference ?? storedPreference()

function resolve(preference: ThemePreference): Theme {
  if (preference !== 'system') return preference
  return window.matchMedia(SYSTEM_DARK).matches ? 'dark' : 'light'
}

function applyTheme(theme: Theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark')
}

function subscribeToClass(onChange: () => void) {
  const observer = new MutationObserver(onChange)
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
  return () => observer.disconnect()
}

const currentTheme = (): Theme => (document.documentElement.classList.contains('dark') ? 'dark' : 'light')

// The theme on <html>. It is null on the server and while the page hydrates, because only the
// browser knows it; React then renders again with the real value.
export function useTheme(): Theme | null {
  return useSyncExternalStore(subscribeToClass, currentTheme, () => null)
}

const preferenceListeners = new Set<() => void>()

function subscribeToPreference(onChange: () => void) {
  preferenceListeners.add(onChange)
  return () => preferenceListeners.delete(onChange)
}

// The visitor's choice, null on the server and while the page hydrates.
export function useThemePreference(): ThemePreference | null {
  return useSyncExternalStore(subscribeToPreference, currentPreference, () => null)
}

// Stores the visitor's choice and applies it. `system` is stored too, so it survives a reload.
export function chooseTheme(preference: ThemePreference) {
  try {
    window.localStorage.setItem(STORAGE_KEY, preference)
    unsavedPreference = null
  } catch {
    unsavedPreference = preference
  }
  applyTheme(resolve(preference))
  preferenceListeners.forEach((listener) => listener())
}

// Follows changes of the system setting while the visitor's choice is `system` (or none).
export function followSystemTheme() {
  window.matchMedia(SYSTEM_DARK).addEventListener('change', (event) => {
    if (currentPreference() === 'system') applyTheme(event.matches ? 'dark' : 'light')
  })
}

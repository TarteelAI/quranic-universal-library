import { useSyncExternalStore } from 'react'

export type Theme = 'light' | 'dark'

// The stored choice. The inline script in app/views/layouts/inertia.html.erb reads the same key
// before the first paint, so the page never flashes the wrong theme: a stored choice wins,
// otherwise the system setting decides.
const STORAGE_KEY = 'qul-theme'
const SYSTEM_DARK = '(prefers-color-scheme: dark)'

function storedTheme(): Theme | null {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY)
    return value === 'light' || value === 'dark' ? value : null
  } catch {
    return null
  }
}

function applyTheme(theme: Theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark')
}

function subscribe(onChange: () => void) {
  const observer = new MutationObserver(onChange)
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
  return () => observer.disconnect()
}

const currentTheme = (): Theme => (document.documentElement.classList.contains('dark') ? 'dark' : 'light')

// The theme on <html>. It is null on the server and while the page hydrates, because only the
// browser knows it; React then renders again with the real value.
export function useTheme(): Theme | null {
  return useSyncExternalStore(subscribe, currentTheme, () => null)
}

// Stores the visitor's choice. From then on it wins over the system setting.
export function chooseTheme(theme: Theme) {
  try {
    window.localStorage.setItem(STORAGE_KEY, theme)
  } catch {
    // Storage can be blocked; the choice then lasts until the next full page load.
  }
  applyTheme(theme)
}

// Follows changes of the system setting while the visitor has made no choice.
export function followSystemTheme() {
  window.matchMedia(SYSTEM_DARK).addEventListener('change', (event) => {
    if (!storedTheme()) applyTheme(event.matches ? 'dark' : 'light')
  })
}

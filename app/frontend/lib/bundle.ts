import * as React from 'react'

// The bundle: the resource ids a visitor has collected, kept in localStorage so the list
// survives a reload and is the same in every tab (the storage event). The server never sees it;
// the tray asks /bundle what the ids are now. When storage is blocked the bundle lasts as long as
// the page. The server and the first render in the browser see an empty bundle, so hydration
// matches whatever the browser holds; React renders again with the stored list right after.

export const BUNDLE_KEY = 'qul-bundle'
// The most ids the tray's lookup reads (Catalog::Bundle::MAX_IDS).
export const BUNDLE_LIMIT = 100

const EMPTY: number[] = []
const listeners = new Set<() => void>()
let current: number[] | null = null

function parse(raw: string | null): number[] {
  if (!raw) return EMPTY
  try {
    const value: unknown = JSON.parse(raw)
    if (!Array.isArray(value)) return EMPTY
    const ids = value.filter((id): id is number => Number.isInteger(id) && id > 0)
    return [...new Set(ids)].slice(0, BUNDLE_LIMIT)
  } catch {
    return EMPTY
  }
}

function load() {
  try {
    return parse(window.localStorage.getItem(BUNDLE_KEY))
  } catch {
    return EMPTY
  }
}

function getSnapshot() {
  return (current ??= load())
}

function getServerSnapshot() {
  return EMPTY
}

function subscribe(listener: () => void) {
  listeners.add(listener)
  const onStorage = (event: StorageEvent) => {
    if (event.key !== null && event.key !== BUNDLE_KEY) return
    current = load()
    listener()
  }
  window.addEventListener('storage', onStorage)
  return () => {
    listeners.delete(listener)
    window.removeEventListener('storage', onStorage)
  }
}

function save(ids: number[]) {
  current = ids.slice(0, BUNDLE_LIMIT)
  try {
    window.localStorage.setItem(BUNDLE_KEY, JSON.stringify(current))
  } catch {
    // Storage is blocked or full: the bundle stays in this page only.
  }
  listeners.forEach((listener) => listener())
}

export function addToBundle(ids: number[]) {
  const bundle = getSnapshot()
  save([...bundle, ...ids.filter((id) => !bundle.includes(id))])
}

export function removeFromBundle(id: number) {
  save(getSnapshot().filter((other) => other !== id))
}

export function toggleInBundle(id: number) {
  if (getSnapshot().includes(id)) removeFromBundle(id)
  else addToBundle([id])
}

// Forgets the list read from storage, so the next read loads it again (tests).
export function resetBundle() {
  current = null
}

/** The ids in the bundle, oldest first. */
export function useBundle() {
  return React.useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)
}

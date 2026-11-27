import { router } from '@inertiajs/react'

/**
 * How long a page fetched ahead (a link's hover or keyboard focus) is kept. For 30 s another
 * hover sends nothing; after that a hover fetches it again, and a click until 5 min shows the
 * kept copy. So a page shown from it is at most 5 min old, which suits catalog data.
 */
export const PREFETCH_CACHE_FOR = ['30s', '5m']

/**
 * Whether a link to a new page is fetched ahead. Not the catalog: every catalog request is a
 * search, and its links carry filters. Not the signed-in user's own pages: they change without
 * an Inertia visit (a download), and hold the user's data.
 */
export function prefetchable(href: string) {
  const path = href.split(/[?#]/)[0]
  return path !== '/resources' && path !== '/profile' && !path.startsWith('/profile/')
}

/**
 * A write (a vote, a request, the account settings) can change what any kept page shows, so
 * each finished visit that is not a GET drops them all. Sign-in and sign-out load a page in
 * full, which starts with nothing kept.
 */
export function flushPrefetchedOnWrite() {
  return router.on('finish', (event) => {
    if (event.detail.visit.method !== 'get') router.flushAll()
  })
}

/**
 * Calls `callback` when a visit starts (to close a menu), but not for a prefetch: Inertia fires
 * `start` for those too, and a menu would close under the pointer resting on one of its links.
 */
export function onVisitStart(callback: () => void) {
  return router.on('start', (event) => {
    if (!event.detail.visit.prefetch) callback()
  })
}

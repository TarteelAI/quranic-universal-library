import * as React from 'react'

export const REPO = 'TarteelAI/quranic-universal-library'
export const REPO_URL = `https://github.com/${REPO}`
// The count on 2026-11-03, shown until the live one loads, when GitHub cannot be reached, and
// in the server render (the count is only fetched in the browser).
const FALLBACK_STARS = 1106

let request: Promise<number> | null = null

/** The repo's star count, fetched once per page load from the public GitHub API. */
export function useGitHubStars(): number {
  const [stars, setStars] = React.useState(FALLBACK_STARS)
  React.useEffect(() => {
    request ??= fetch(`https://api.github.com/repos/${REPO}`)
      .then((response) => (response.ok ? response.json() : null))
      .then((repo) => (typeof repo?.stargazers_count === 'number' ? repo.stargazers_count : FALLBACK_STARS))
      .catch(() => FALLBACK_STARS)
    let live = true
    request.then((count) => live && setStars(count))
    return () => {
      live = false
    }
  }, [])
  return stars
}

/** 1106 → "1.1k" */
export function formatStars(count: number): string {
  return count >= 1000 ? `${(count / 1000).toFixed(count >= 10000 ? 0 : 1).replace(/\.0$/, '')}k` : String(count)
}

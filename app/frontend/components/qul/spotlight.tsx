import { router, usePage } from '@inertiajs/react'
import { ArrowRightIcon, SearchIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Kbd } from '@/components/ui/misc'
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from '@/components/ui/overlays'
import { cn } from '@/lib/utils'
import { catalogResources, catalogSpotlight, detailResources } from '@/routes'
import type { CatalogSpotlightResult } from '@/types/serializers'

// Typing waits this long for a pause before it asks the server.
const DEBOUNCE_MS = 250

type Answer = { q: string; results: CatalogSpotlightResult[]; total: number }
type Item = { id: string; label: string; detail?: string; href: string; inertia: boolean }

const noSubscription = () => () => {}

/** "⌘K" on Apple devices, "Ctrl K" elsewhere; null on the server and while hydrating. */
function useShortcutLabel() {
  return React.useSyncExternalStore(
    noSubscription,
    () => (/Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent) ? '⌘K' : 'Ctrl K'),
    () => null,
  )
}

// The answer for the latest query only: each new query aborts the request before it, and an
// answer is kept with the query it is for, so an older query's results are never shown.
function useSpotlightSearch(query: string) {
  const [answer, setAnswer] = React.useState<Answer | null>(null)

  React.useEffect(() => {
    if (!query) return
    const controller = new AbortController()
    const timer = window.setTimeout(async () => {
      try {
        const response = await fetch(catalogSpotlight.index({ query: { q: query } }).url, {
          headers: { Accept: 'application/json' },
          signal: controller.signal,
        })
        if (response.ok) setAnswer({ q: query, ...((await response.json()) as Omit<Answer, 'q'>) })
      } catch (error) {
        if (!controller.signal.aborted) throw error
      }
    }, DEBOUNCE_MS)
    return () => {
      window.clearTimeout(timer)
      controller.abort()
    }
  }, [query])

  return answer?.q === query ? answer : null
}

function statusLine(query: string, answer: Answer | null) {
  if (!query) return 'Type to search the catalog.'
  if (!answer) return 'Searching…'
  if (answer.total === 0) return `No resources match “${query}”.`
  return null
}

function go(item: Item) {
  if (item.inertia) router.visit(item.href)
  else window.location.assign(item.href)
}

interface SpotlightPanelProps {
  onNavigate: () => void
}

function SpotlightPanel({ onNavigate }: SpotlightPanelProps) {
  const { nav } = usePage().props
  const [input, setInput] = React.useState('')
  const [active, setActive] = React.useState(0)
  const query = input.trim()
  const answer = useSpotlightSearch(query)
  const listId = React.useId()

  const all: Item = query
    ? {
        id: 'all',
        label: answer ? `All ${answer.total} results for “${query}”` : `All results for “${query}”`,
        href: catalogResources.index({ query: { q: query } }).url,
        inertia: nav.search.inertia,
      }
    : { id: 'all', label: 'Browse all resources', href: nav.search.href, inertia: nav.search.inertia }
  const items: Item[] = [
    ...(answer?.results ?? []).map((result) => ({
      id: String(result.id),
      label: result.name,
      detail: [result.typeLabel, result.language].filter(Boolean).join(' · '),
      href: detailResources({ type: result.type, id: result.toParam }).url,
      inertia: false,
    })),
    all,
  ]
  const current = Math.min(active, items.length - 1)
  const optionId = (index: number) => `${listId}-${index}`

  const choose = (item: Item) => {
    onNavigate()
    go(item)
  }

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      const step = event.key === 'ArrowDown' ? 1 : -1
      setActive((current + step + items.length) % items.length)
    } else if (event.key === 'Enter') {
      event.preventDefault()
      choose(items[current])
    }
  }

  const status = statusLine(query, answer)

  return (
    <>
      <div className="flex items-center gap-3 border-b px-4">
        <SearchIcon className="size-5 shrink-0 text-muted-foreground" />
        <input
          type="text"
          role="combobox"
          aria-label="Search resources"
          aria-expanded="true"
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={optionId(current)}
          autoComplete="off"
          spellCheck={false}
          placeholder="Search by name, language or type…"
          className="h-14 min-w-0 flex-1 bg-transparent text-base outline-none placeholder:text-muted-foreground"
          value={input}
          onChange={(event) => {
            setInput(event.target.value)
            setActive(0)
          }}
          onKeyDown={onKeyDown}
        />
      </div>
      <div className="max-h-[min(60vh,28rem)] overflow-y-auto overscroll-contain p-2">
        {status && (
          <p role="status" className="px-3 py-2 text-sm text-muted-foreground">
            {status}
          </p>
        )}
        <ul id={listId} role="listbox" aria-label="Search results" className="flex flex-col gap-0.5">
          {items.map((item, index) => (
            <li
              key={item.id}
              id={optionId(index)}
              role="option"
              aria-selected={index === current}
              onMouseMove={() => setActive(index)}
              onClick={() => choose(item)}
              className={cn(
                'flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 text-sm',
                index === current && 'bg-secondary',
                item === all && 'text-muted-foreground',
              )}
            >
              <span className="min-w-0 flex-1">
                <span className={cn('block truncate', item !== all && 'font-medium text-foreground')}>
                  {item.label}
                </span>
                {item.detail && <span className="block truncate text-xs text-muted-foreground">{item.detail}</span>}
              </span>
              {index === current && <ArrowRightIcon className="size-4 shrink-0 text-muted-foreground" />}
            </li>
          ))}
        </ul>
      </div>
    </>
  )
}

/**
 * Catalog search from any new page: the header's search button, or ⌘K / Ctrl K. Results come
 * from /spotlight as the user types; Enter opens the highlighted resource, or the catalog with
 * every result. Closing returns focus to where it was.
 */
function Spotlight() {
  const [open, setOpen] = React.useState(false)
  const returnFocus = React.useRef<HTMLElement | null>(null)
  const shortcut = useShortcutLabel()

  React.useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'k' || !(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) return
      event.preventDefault()
      setOpen((wasOpen) => {
        if (!wasOpen) {
          const focused = document.activeElement
          returnFocus.current = focused instanceof HTMLElement && focused !== document.body ? focused : null
        }
        return !wasOpen
      })
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [])

  const close = React.useCallback(() => setOpen(false), [])

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Search resources"
          className={cn(shortcut && 'lg:w-auto lg:gap-2 lg:px-2')}
          onClick={() => (returnFocus.current = null)}
        >
          <SearchIcon />
          {shortcut && <Kbd className="hidden lg:inline-flex">{shortcut}</Kbd>}
        </Button>
      </DialogTrigger>
      <DialogContent
        className="top-[12vh] translate-y-0 gap-0 overflow-hidden p-0 sm:max-w-xl [&>button:last-child]:hidden"
        onCloseAutoFocus={(event) => {
          if (!returnFocus.current?.isConnected) return
          event.preventDefault()
          returnFocus.current.focus()
        }}
      >
        <DialogTitle className="sr-only">Search resources</DialogTitle>
        <DialogDescription className="sr-only">
          Type to search. Use the arrow keys to pick a result and Enter to open it.
        </DialogDescription>
        <SpotlightPanel onNavigate={close} />
      </DialogContent>
    </Dialog>
  )
}

export { Spotlight }

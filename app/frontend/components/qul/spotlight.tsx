import { router, usePage } from '@inertiajs/react'
import {
  ArrowRightIcon,
  ArrowUpRightIcon,
  BookOpenIcon,
  BracesIcon,
  CompassIcon,
  CornerDownLeftIcon,
  FileTextIcon,
  HandHeartIcon,
  LibraryIcon,
  SearchIcon,
  WrenchIcon,
} from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Kbd } from '@/components/ui/misc'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/overlays'
import { cn } from '@/lib/utils'
import { catalogResources, catalogSpotlight, detailResources } from '@/routes'
import type { CatalogSpotlightResult, SiteNav, SiteNavGroup, SiteNavLink } from '@/types/serializers'

import { ResourceIcon } from './icons'
import { navIcon } from './nav'

// Typing waits this long for a pause before it asks the server.
const DEBOUNCE_MS = 250
// At most this many pages and this many tools are shown for a query.
const NAV_LIMIT = 4

type Found = { results: CatalogSpotlightResult[]; total: number }
type Answer = Found & { q: string; failed: boolean }
type Item = {
  id: string
  label: string
  detail?: string
  href: string
  inertia: boolean
  external?: boolean
  icon?: React.ReactNode
}
type Section = { heading: string; items: Item[] }
// A navigation link, with the words it is found by that are not shown.
type NavItem = Item & { group: 'Pages' | 'Tools'; keywords: string }

const noSubscription = () => () => {}

/** "⌘K" on Apple devices, "Ctrl K" elsewhere; null on the server and while hydrating. */
function useShortcutLabel() {
  return React.useSyncExternalStore(
    noSubscription,
    () => (/Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent) ? '⌘K' : 'Ctrl K'),
    () => null,
  )
}

// One request to /spotlight. Null when it fails for any reason (a non-OK answer, the network, an
// abort): the spotlight then says so and keeps pages, tools and the catalog search working.
async function fetchSpotlight(query: string, signal?: AbortSignal): Promise<Found | null> {
  try {
    const response = await fetch(catalogSpotlight.index(query ? { query: { q: query } } : undefined).url, {
      headers: { Accept: 'application/json' },
      signal,
    })
    return response.ok ? ((await response.json()) as Found) : null
  } catch {
    return null
  }
}

// The popular resources are asked for once per page load, on the first open, and kept for every
// later open. A failed request is not kept, so the next open asks again.
let popularRequest: Promise<CatalogSpotlightResult[] | null> | null = null
let popularResults: CatalogSpotlightResult[] | null = null

function usePopularResources() {
  const [results, setResults] = React.useState<CatalogSpotlightResult[]>(popularResults ?? [])

  React.useEffect(() => {
    if (popularResults) return
    let mounted = true
    popularRequest ??= fetchSpotlight('').then((found) => {
      popularResults = found?.results ?? null
      if (!found) popularRequest = null
      return popularResults
    })
    void popularRequest.then((found) => {
      if (mounted && found) setResults(found)
    })
    return () => {
      mounted = false
    }
  }, [])

  return results
}

// The answer for the latest query only: each new query aborts the request before it, and an
// answer is kept with the query it is for, so an older query's results are never shown.
function useSpotlightSearch(query: string) {
  const [answer, setAnswer] = React.useState<Answer | null>(null)

  React.useEffect(() => {
    if (!query) return
    const controller = new AbortController()
    const timer = window.setTimeout(async () => {
      const found = await fetchSpotlight(query, controller.signal)
      if (controller.signal.aborted) return
      setAnswer(found ? { q: query, ...found, failed: false } : { q: query, results: [], total: 0, failed: true })
    }, DEBOUNCE_MS)
    return () => {
      window.clearTimeout(timer)
      controller.abort()
    }
  }, [query])

  return answer?.q === query ? answer : null
}

const tile = (icon: React.ReactNode) => (
  <span className="inline-flex size-7 shrink-0 items-center justify-center rounded-[28%] border bg-card text-foreground [&_svg]:size-4">
    {icon}
  </span>
)

// Docs are left out of the results until the docs pages move to the new site and are indexed.
const isDocs = (link: Pick<SiteNavLink, 'href'>) => /^\/docs(\/|$)/.test(link.href)

// The detail page belongs to the catalog page group, as the catalog search link does.
function resourceItem(result: CatalogSpotlightResult, inertia: boolean): Item {
  return {
    id: `resource:${result.id}`,
    label: result.name,
    detail: [result.typeLabel, result.language, result.formats.join(', ')].filter(Boolean).join(' · '),
    href: detailResources({ type: result.type, id: result.toParam }).url,
    inertia,
    icon: <ResourceIcon category={result.category} size="sm" />,
  }
}

// The parts of a link a result is made from: a menu's overview link has only the first three.
type NavLinkLike = Pick<SiteNavLink, 'label' | 'href' | 'inertia'> & Partial<SiteNavLink>

function linkIcon(link: NavLinkLike, group: NavItem['group']) {
  if (link.category) return <ResourceIcon category={link.category} size="sm" />
  if (link.icon) {
    const Icon = navIcon(link.icon)
    return tile(<Icon />)
  }
  return tile(group === 'Tools' ? <WrenchIcon /> : <FileTextIcon />)
}

function navItem(link: NavLinkLike, group: NavItem['group'], keywords: string): NavItem {
  return {
    id: `nav:${link.href}`,
    label: link.label,
    detail: link.description ?? undefined,
    href: link.href,
    inertia: link.inertia,
    external: link.external,
    icon: linkIcon(link, group),
    group,
    keywords,
  }
}

/**
 * The pages and contribution tools the site navigation links to, one item per address. A link
 * is a tool exactly when its group is a tools group (SiteNavGroup#tools); every other link is a
 * page. Tools are listed first, so an address that is both keeps the tool, with its own label.
 */
function navSearchItems(nav: SiteNav): NavItem[] {
  const tools: NavItem[] = []
  const pages: NavItem[] = [navItem(nav.home, 'Pages', '')]
  const add = (group: SiteNavGroup, keywords: string) => {
    for (const link of group.links)
      if (group.tools) tools.push(navItem(link, 'Tools', keywords))
      else pages.push(navItem(link, 'Pages', keywords))
  }
  for (const menu of nav.menus) {
    pages.push(navItem({ label: menu.overview, href: menu.href, inertia: menu.inertia }, 'Pages', menu.label))
    for (const group of [...menu.groups, ...menu.aside]) add(group, `${menu.label} ${group.heading}`)
  }
  for (const group of nav.footer) add(group, group.heading)

  const byHref = new Map<string, NavItem>()
  for (const item of [...tools, ...pages]) if (!isDocs(item) && !byHref.has(item.href)) byHref.set(item.href, item)
  return [...byHref.values()]
}

/** Every query word must appear; hits in the label rank first. */
function score(item: NavItem, words: string[]) {
  const label = item.label.toLowerCase()
  const text = `${label} ${item.detail ?? ''} ${item.keywords}`.toLowerCase()
  if (!words.every((word) => text.includes(word))) return 0
  const query = words.join(' ')
  if (label.startsWith(query)) return 4
  if (label.includes(query)) return 3
  if (words.every((word) => label.includes(word))) return 2
  return 1
}

function matchNav(items: NavItem[], query: string, group: NavItem['group']) {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean)
  return items
    .filter((item) => item.group === group)
    .map((item) => ({ item, score: score(item, words) }))
    .filter((hit) => hit.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, NAV_LIMIT)
    .map((hit) => hit.item)
}

const QUICK_LINK_ICONS: Record<string, React.ReactNode> = {
  resources: <LibraryIcon />,
  docs: <BookOpenIcon />,
  developers: <BracesIcon />,
  contribute: <HandHeartIcon />,
}

// The overview link of each menu: the catalog, the docs, the API docs, the contribution tools.
function quickLinks(nav: SiteNav): Item[] {
  return nav.menus.map((menu) => ({
    id: `quick:${menu.href}`,
    label: menu.overview,
    href: menu.href,
    inertia: menu.inertia,
    icon: tile(QUICK_LINK_ICONS[menu.label.toLowerCase()] ?? <CompassIcon />),
  }))
}

function go(item: Item) {
  if (item.external) window.open(item.href, '_blank', 'noreferrer')
  else if (item.inertia) router.visit(item.href)
  else window.location.assign(item.href)
}

interface SpotlightPanelProps {
  shortcut: string | null
  onNavigate: () => void
}

function SpotlightPanel({ shortcut, onNavigate }: SpotlightPanelProps) {
  const { nav } = usePage().props
  const [input, setInput] = React.useState('')
  const [activeId, setActiveId] = React.useState<string | null>(null)
  const query = input.trim()
  const popular = usePopularResources()
  const answer = useSpotlightSearch(query)
  const navItems = React.useMemo(() => navSearchItems(nav), [nav])
  const listId = React.useId()
  const listRef = React.useRef<HTMLUListElement>(null)

  const toItem = (result: CatalogSpotlightResult) => resourceItem(result, nav.search.inertia)
  const quick = quickLinks(nav)
  const sections: Section[] = query
    ? [
        { heading: 'Resources', items: (answer?.results ?? []).map(toItem) },
        { heading: 'Pages', items: matchNav(navItems, query, 'Pages') },
        { heading: 'Tools', items: matchNav(navItems, query, 'Tools') },
      ]
    : [
        { heading: 'Popular resources', items: popular.map(toItem) },
        { heading: 'Quick links', items: quick },
      ]
  const visible = sections.filter((section) => section.items.length > 0)
  const all: Item | null = query
    ? {
        id: 'all',
        label: answer && !answer.failed ? `All ${answer.total} results for “${query}”` : `All results for “${query}”`,
        href: catalogResources.index({ query: { q: query } }).url,
        inertia: nav.search.inertia,
        icon: <SearchIcon className="size-4 shrink-0" />,
      }
    : null
  const items = [...visible.flatMap((section) => section.items), ...(all ? [all] : [])]
  // The highlight is kept on an item, not a position, so results that arrive later never move it
  // and Enter opens what the user sees highlighted. It starts on the first quick link when
  // nothing is typed (Enter on open goes to the catalog), else on the first item shown.
  const kept = items.findIndex((item) => item.id === activeId)
  const start = query ? 0 : Math.max(items.indexOf(quick[0]), 0)
  const current = kept >= 0 ? kept : start
  const currentId = items[current]?.id
  if (currentId && currentId !== activeId) setActiveId(currentId)
  const optionId = (index: number) => `${listId}-${index}`

  React.useEffect(() => {
    listRef.current?.querySelector(`[data-index="${current}"]`)?.scrollIntoView?.({ block: 'nearest' })
  }, [current])

  let status: string | null = null
  if (query && !answer) status = 'Searching…'
  else if (answer?.failed) status = 'Resources could not be loaded. Pages, tools and the full search still work.'
  else if (query && items.length === 1) status = `No resources, pages or tools match “${query}”.`

  const choose = (item: Item) => {
    onNavigate()
    go(item)
  }

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (!items.length) return
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      const step = event.key === 'ArrowDown' ? 1 : -1
      setActiveId(items[(current + step + items.length) % items.length].id)
    } else if (event.key === 'Enter' && !event.nativeEvent.isComposing) {
      event.preventDefault()
      choose(items[current])
    }
  }

  const option = (item: Item) => {
    const i = items.indexOf(item)
    const on = i === current
    return (
      <li
        key={item.id}
        id={optionId(i)}
        data-index={i}
        role="option"
        aria-selected={on}
        onMouseMove={() => activeId !== item.id && setActiveId(item.id)}
        onClick={() => choose(item)}
        className={cn(
          'flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 text-sm',
          on && 'bg-foreground/[0.055]',
          item === all && 'mt-1 text-muted-foreground',
        )}
      >
        {item.icon}
        <span className="flex min-w-0 flex-1 flex-col">
          <span className={cn('flex items-center gap-1', item !== all && 'font-medium text-foreground')}>
            <span className="truncate">{item.label}</span>
            {item.external && <ArrowUpRightIcon className="size-3.5 shrink-0 text-muted-foreground" />}
          </span>
          {item.detail && <span className="truncate text-[13px] text-muted-foreground">{item.detail}</span>}
        </span>
        <ArrowRightIcon className={cn('size-4 shrink-0 text-muted-foreground', !on && 'invisible')} />
      </li>
    )
  }

  return (
    <>
      <div className="flex shrink-0 items-center gap-3 border-b px-4">
        <SearchIcon className="size-5 shrink-0 text-muted-foreground" />
        <input
          type="text"
          role="combobox"
          aria-label="Search QUL"
          aria-expanded="true"
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={items.length ? optionId(current) : undefined}
          autoComplete="off"
          spellCheck={false}
          placeholder="Search resources, pages and tools…"
          className="h-14 min-w-0 flex-1 bg-transparent text-base outline-none placeholder:text-muted-foreground"
          value={input}
          onChange={(event) => {
            setInput(event.target.value)
            setActiveId(null)
          }}
          onKeyDown={onKeyDown}
        />
        <DialogClose
          aria-label="Close search"
          className="shrink-0 rounded-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
        >
          <Kbd className="hover:text-foreground">Esc</Kbd>
        </DialogClose>
      </div>
      <div className="max-h-[min(60vh,28rem)] overflow-y-auto overscroll-contain p-2">
        {status && (
          <p role="status" className="px-3 py-2 text-sm text-muted-foreground">
            {status}
          </p>
        )}
        <ul ref={listRef} id={listId} role="listbox" aria-label="Search results" className="flex flex-col">
          {visible.map((section) => (
            <li key={section.heading} role="presentation" className="pb-1">
              <p aria-hidden="true" className="px-3 pt-2 pb-1.5 text-xs text-muted-foreground">
                {section.heading}
              </p>
              <ul role="group" aria-label={section.heading} className="flex flex-col gap-0.5">
                {section.items.map(option)}
              </ul>
            </li>
          ))}
          {all && option(all)}
        </ul>
      </div>
      <div className="hidden shrink-0 items-center gap-4 border-t px-4 py-2.5 text-xs text-muted-foreground sm:flex">
        <span className="inline-flex items-center gap-1.5">
          <Kbd>↑</Kbd>
          <Kbd>↓</Kbd> to move
        </span>
        <span className="inline-flex items-center gap-1.5">
          <Kbd>
            <CornerDownLeftIcon className="size-3" />
          </Kbd>{' '}
          to open
        </span>
        {shortcut && (
          <span className="ms-auto inline-flex items-center gap-1.5">
            <Kbd>{shortcut}</Kbd> to close
          </span>
        )}
      </div>
    </>
  )
}

export interface SpotlightProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Search from any new page: the header's search button, or ⌘K / Ctrl K. On open it shows the
 * most popular resources and quick links; as the user types, catalog results from /spotlight
 * and the pages and contribution tools of the site navigation. Enter opens the highlighted
 * result, or the catalog with every result. Closing returns focus to where it was.
 */
function Spotlight({ open, onOpenChange }: SpotlightProps) {
  const returnFocus = React.useRef<HTMLElement | null>(null)
  const shortcut = useShortcutLabel()

  React.useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'k' || !(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) return
      event.preventDefault()
      if (!open) {
        const focused = document.activeElement
        returnFocus.current = focused instanceof HTMLElement && focused !== document.body ? focused : null
      }
      onOpenChange(!open)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [open, onOpenChange])

  const close = React.useCallback(() => onOpenChange(false), [onOpenChange])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Search resources"
          className={cn(shortcut && 'lg:w-auto lg:gap-2 lg:px-2')}
        >
          <SearchIcon />
          {shortcut && <Kbd className="hidden lg:inline-flex">{shortcut}</Kbd>}
        </Button>
      </DialogTrigger>
      <DialogContent
        className="top-[max(1rem,10vh)] max-h-[min(36rem,calc(100dvh-2rem))] translate-y-0 gap-0 overflow-hidden p-0 sm:max-w-xl [&>button:last-child]:hidden"
        onCloseAutoFocus={(event) => {
          const target = returnFocus.current
          returnFocus.current = null
          if (!target?.isConnected) return
          event.preventDefault()
          target.focus()
        }}
      >
        <DialogTitle className="sr-only">Search QUL</DialogTitle>
        <DialogDescription className="sr-only">
          Type to search resources, pages and tools. Use the arrow keys to pick a result and Enter to open it.
        </DialogDescription>
        <SpotlightPanel shortcut={shortcut} onNavigate={close} />
      </DialogContent>
    </Dialog>
  )
}

export { Spotlight, navSearchItems }

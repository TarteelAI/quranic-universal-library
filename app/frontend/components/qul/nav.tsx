import { Link, router } from '@inertiajs/react'
import { ArrowRightIcon, ArrowUpRightIcon, ChevronDownIcon } from 'lucide-react'
import { Accordion as AccordionPrimitive, NavigationMenu as NavPrimitive } from 'radix-ui'
import * as React from 'react'

import { cn } from '@/lib/utils'
import type { SiteNavGroup, SiteNavLink, SiteNavMenu } from '@/types/serializers'

import { ResourceIcon } from './icons'

/* ---------------- links ---------------- */

type NavTarget = Pick<SiteNavLink, 'href' | 'inertia'> & { external?: boolean }

// The props an anchor in the navigation needs. Radix (NavigationMenu.Link asChild) passes more,
// such as its key handlers, and they reach the anchor too.
export interface NavAnchorProps {
  link: NavTarget
  className?: string
  children?: React.ReactNode
  onClick?: (event: React.MouseEvent<Element>) => void
  'aria-label'?: string
  ref?: React.Ref<HTMLAnchorElement>
}

/**
 * A link from the site navigation. A link to a new page is an Inertia visit; any other link
 * (an old page, another site) is a plain link that loads the page in full.
 */
function NavAnchor({ link, children, ref, ...props }: NavAnchorProps) {
  if (link.inertia)
    return (
      <Link ref={ref} href={link.href} {...props}>
        {children}
      </Link>
    )
  return (
    <a ref={ref} href={link.href} {...(link.external ? { target: '_blank', rel: 'noreferrer' } : {})} {...props}>
      {children}
    </a>
  )
}

// Follows a link from code (a click on a menu trigger), the same way NavAnchor would.
function visit(link: NavTarget) {
  if (link.inertia) router.visit(link.href)
  else window.location.assign(link.href)
}

// The menu of the section the current page is in.
export function isMenuActive(menu: SiteNavMenu, url: string) {
  const path = url.split(/[?#]/)[0]
  return path === menu.href || path.startsWith(`${menu.href}/`)
}

function LinkIcon({ link }: { link: SiteNavLink }) {
  return link.category ? <ResourceIcon category={link.category} size="sm" /> : null
}

/* ---------------- desktop mega menu ---------------- */

function PanelLink({ link, compact }: { link: SiteNavLink; compact?: boolean }) {
  return (
    <NavPrimitive.Link asChild>
      <NavAnchor
        link={link}
        className={cn(
          'group/link flex gap-3 rounded-lg outline-none transition-colors hover:bg-foreground/[0.045] focus-visible:bg-foreground/[0.045] focus-visible:ring-[3px] focus-visible:ring-ring/40',
          compact ? 'items-center px-2 py-1.5' : 'items-start p-2.5',
        )}
      >
        <LinkIcon link={link} />
        <span className="flex min-w-0 flex-col gap-0.5">
          <span className="flex items-center gap-1 text-sm font-medium text-foreground">
            {link.label}
            {link.external && <ArrowUpRightIcon className="size-3.5 text-muted-foreground" />}
          </span>
          {link.description && !compact && (
            <span className="line-clamp-2 text-[13px] leading-snug text-muted-foreground">{link.description}</span>
          )}
        </span>
      </NavAnchor>
    </NavPrimitive.Link>
  )
}

// Panel width in rem: two columns for a wide group, plus the side rail.
function panelWidth(menu: SiteNavMenu) {
  return (menu.groups.some((group) => group.wide) ? 32 : 20) + (menu.aside.length ? 14 : 0)
}

function Panel({ menu }: { menu: SiteNavMenu }) {
  return (
    <div className="flex flex-col" style={{ width: `${panelWidth(menu)}rem` }}>
      <div className={cn('grid gap-2 p-3', menu.aside.length > 0 && 'grid-cols-[1fr_13.5rem]')}>
        <div className="flex flex-col gap-3 p-1">
          {menu.groups.map((group) => (
            <div key={group.heading}>
              <p className="px-2.5 pt-1 pb-2 text-xs text-muted-foreground">{group.heading}</p>
              <div className={cn('grid gap-0.5', group.wide && 'grid-cols-2')}>
                {group.links.map((link) => (
                  <PanelLink key={link.label} link={link} compact={!link.description} />
                ))}
              </div>
            </div>
          ))}
        </div>
        {menu.aside.length > 0 && (
          <div className="flex flex-col gap-4 rounded-xl bg-surface p-3">
            {menu.aside.map((group) => (
              <div key={group.heading}>
                <p className="px-2 pt-1 pb-2 text-xs text-muted-foreground">{group.heading}</p>
                <div className="flex flex-col gap-0.5">
                  {group.links.map((link) => (
                    <PanelLink key={link.label} link={link} compact={!link.description} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      <NavPrimitive.Link asChild>
        <NavAnchor
          link={menu}
          className="group/ov flex items-center gap-1.5 border-t px-5 py-3 text-sm font-medium text-foreground outline-none hover:bg-foreground/[0.03] focus-visible:bg-foreground/[0.045]"
        >
          {menu.overview}
          <ArrowRightIcon className="size-3.5 transition-transform group-hover/ov:translate-x-0.5" />
        </NavAnchor>
      </NavPrimitive.Link>
    </div>
  )
}

export interface MegaMenuProps {
  menus: SiteNavMenu[]
  /** The current page's URL, which marks its section's menu */
  url: string
  className?: string
}

/**
 * Desktop header nav. Each item opens a panel on hover or click; the panel morphs between
 * items, stays open while the pointer travels into it, and closes on Escape, link select,
 * outside click and every Inertia visit.
 */
function MegaMenu({ menus, url, className }: MegaMenuProps) {
  const [value, setValue] = React.useState('')
  // The panel sits under its own trigger (clamped to the window), so the pointer goes straight down into it
  const [offset, setOffset] = React.useState({ x: 0, slide: false })
  const rootRef = React.useRef<HTMLElement>(null)
  const pointerType = React.useRef('')
  React.useEffect(() => router.on('start', () => setValue('')), [])

  const onValueChange = (next: string) => {
    const root = rootRef.current
    const trigger = root?.querySelector<HTMLElement>(`[data-menu="${CSS.escape(next)}"]`)
    const menu = menus.find((m) => m.label === next)
    if (root && trigger && menu) {
      const r = root.getBoundingClientRect()
      const rem = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16
      const maxX = window.innerWidth - 16 - r.left - panelWidth(menu) * rem
      const x = Math.max(Math.min(trigger.getBoundingClientRect().left - r.left, maxX), 16 - r.left)
      setOffset({ x, slide: value !== '' })
    }
    setValue(next)
  }

  return (
    <NavPrimitive.Root
      ref={rootRef}
      value={value}
      onValueChange={onValueChange}
      delayDuration={120}
      skipDelayDuration={400}
      aria-label="Main"
      className={cn('relative h-full items-center [&>div:first-child]:h-full', className)}
    >
      <NavPrimitive.List className="flex h-full items-center">
        {menus.map((menu) => {
          const active = isMenuActive(menu, url)
          return (
            <NavPrimitive.Item key={menu.label} value={menu.label} className="flex h-full items-center">
              {/* The trigger spans the full header height so the pointer stays on it until it reaches the panel */}
              <NavPrimitive.Trigger
                data-menu={menu.label}
                aria-current={active ? 'page' : undefined}
                // A mouse click opens the section's page (hover already shows the panel); touch and keyboard still toggle the panel
                onPointerDown={(e) => (pointerType.current = e.pointerType)}
                onClick={(e) => {
                  if (e.detail === 0 || pointerType.current !== 'mouse') return
                  e.preventDefault()
                  setValue('')
                  visit(menu)
                }}
                className="group flex h-full items-center px-0.5 outline-none"
              >
                <span
                  className={cn(
                    'inline-flex h-8 items-center gap-1 rounded-full px-2.5 text-sm whitespace-nowrap text-muted-foreground transition-colors group-hover:text-foreground group-focus-visible:ring-[3px] group-focus-visible:ring-ring/40 group-data-[state=open]:bg-foreground/[0.06] group-data-[state=open]:text-foreground xl:px-3',
                    active && 'font-medium text-foreground',
                  )}
                >
                  {menu.label}
                  <ChevronDownIcon
                    aria-hidden
                    className="hidden size-3.5 opacity-60 transition-transform duration-200 group-data-[state=open]:rotate-180 motion-reduce:transition-none xl:block"
                  />
                </span>
              </NavPrimitive.Trigger>
              <NavPrimitive.Content className="absolute top-0 left-0 data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out data-[motion=from-end]:slide-in-from-right-6 data-[motion=from-start]:slide-in-from-left-6 data-[motion=to-end]:slide-out-to-right-6 data-[motion=to-start]:slide-out-to-left-6 motion-reduce:animate-none">
                <Panel menu={menu} />
              </NavPrimitive.Content>
            </NavPrimitive.Item>
          )
        })}
      </NavPrimitive.List>
      <div
        className={cn(
          'absolute top-full left-0 pt-1.5',
          offset.slide && 'transition-transform duration-250 ease-out motion-reduce:transition-none',
        )}
        style={{ transform: `translateX(${offset.x}px)` }}
      >
        <NavPrimitive.Viewport className="relative h-(--radix-navigation-menu-viewport-height) w-(--radix-navigation-menu-viewport-width) origin-top-left overflow-hidden rounded-2xl border bg-popover text-popover-foreground shadow-[0_12px_40px_-12px_oklch(0.2_0.03_152/0.25)] transition-[width,height] duration-250 ease-out data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-[0.98] data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-[0.98] motion-reduce:transition-none" />
      </div>
    </NavPrimitive.Root>
  )
}

/* ---------------- mobile sections ---------------- */

export interface MobileNavProps {
  menus: SiteNavMenu[]
  url: string
  /** Called after any link is tapped (close the sheet) */
  onNavigate?: () => void
  className?: string
}

const allGroups = (menu: SiteNavMenu): SiteNavGroup[] => [...menu.groups, ...menu.aside]

/** The same menus as the mega menu, as collapsible sections for the mobile sheet. */
function MobileNav({ menus, url, onNavigate, className }: MobileNavProps) {
  return (
    <AccordionPrimitive.Root type="single" collapsible className={cn('flex flex-col', className)}>
      {menus.map((menu) => (
        <AccordionPrimitive.Item key={menu.label} value={menu.label} className="border-b">
          <AccordionPrimitive.Header>
            <AccordionPrimitive.Trigger className="group flex w-full items-center justify-between py-3.5 text-left text-base font-medium outline-none focus-visible:ring-[3px] focus-visible:ring-ring/40">
              <span className="flex items-center gap-2">
                {menu.label}
                {isMenuActive(menu, url) && (
                  <span className="size-1.5 rounded-full bg-brand" aria-label="(current section)" />
                )}
              </span>
              <ChevronDownIcon className="size-4 text-muted-foreground transition-transform duration-200 group-data-[state=open]:rotate-180" />
            </AccordionPrimitive.Trigger>
          </AccordionPrimitive.Header>
          <AccordionPrimitive.Content className="overflow-hidden data-[state=closed]:animate-accordion-up data-[state=open]:animate-accordion-down motion-reduce:animate-none">
            <div className="flex flex-col gap-3 pb-4">
              {allGroups(menu).map((group) => (
                <div key={group.heading}>
                  <p className="pb-1 text-xs text-muted-foreground">{group.heading}</p>
                  <ul className="flex flex-col">
                    {group.links.map((link) => (
                      <li key={link.label}>
                        <NavAnchor
                          link={link}
                          onClick={onNavigate}
                          className="-mx-2 flex min-h-11 items-center gap-3 rounded-lg px-2 py-1.5 text-[15px] active:bg-foreground/[0.06]"
                        >
                          <LinkIcon link={link} />
                          <span className="flex-1">{link.label}</span>
                          {link.external && <ArrowUpRightIcon className="size-4 text-muted-foreground" />}
                        </NavAnchor>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
              {!allGroups(menu).some((group) => group.links.some((link) => link.href === menu.href)) && (
                <NavAnchor
                  link={menu}
                  onClick={onNavigate}
                  className="flex min-h-11 items-center gap-1.5 text-[15px] font-medium"
                >
                  {menu.overview} <ArrowRightIcon className="size-4" />
                </NavAnchor>
              )}
            </div>
          </AccordionPrimitive.Content>
        </AccordionPrimitive.Item>
      ))}
    </AccordionPrimitive.Root>
  )
}

export { MegaMenu, MobileNav, NavAnchor }

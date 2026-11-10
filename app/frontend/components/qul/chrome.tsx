import { router, usePage } from '@inertiajs/react'
import { ArrowUpRightIcon, LogOutIcon, MenuIcon, SearchIcon } from 'lucide-react'
import { DropdownMenu as DropdownPrimitive } from 'radix-ui'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Kbd } from '@/components/ui/misc'
import { Dialog, DialogContent, DialogTitle, DialogTrigger } from '@/components/ui/overlays'
import { fillAuthenticityToken } from '@/lib/csrf'
import { REPO_URL } from '@/lib/github'
import { cn } from '@/lib/utils'
import { destroyUserSession, newUserSession } from '@/routes'
import type { AuthUser, SiteNavGroup } from '@/types/serializers'

import { GitHubMark } from './icons'
import { MARK_SVG, WORDMARK_SVG } from './logo-paths'
import { MegaMenu, MobileNav, NavAnchor } from './nav'
import { Spotlight } from './spotlight'
import { ThemeToggle } from './theme'

/* ---------------- Logo ---------------- */

export interface LogoProps {
  /** `wordmark` = full "Quranic Universal Library" lockup; `mark` = icon only; `lockup` = mark + "QUL" */
  variant?: 'wordmark' | 'mark' | 'lockup'
  className?: string
}

function Logo({ variant = 'lockup', className }: LogoProps) {
  if (variant === 'wordmark')
    return (
      <svg
        viewBox="0 0 234 63"
        className={cn('h-10 w-auto', className)}
        role="img"
        aria-label="Quranic Universal Library"
        dangerouslySetInnerHTML={{ __html: WORDMARK_SVG }}
      />
    )
  const mark = (
    <svg
      viewBox="0 0 32 40"
      className="h-7 w-auto shrink-0"
      aria-hidden="true"
      dangerouslySetInnerHTML={{ __html: MARK_SVG }}
    />
  )
  if (variant === 'mark') return <span className={cn('inline-flex', className)}>{mark}</span>
  return (
    <span className={cn('inline-flex items-center gap-2', className)}>
      {mark}
      <span className="leading-none">
        <span className="block text-[17px] font-semibold tracking-tight">QUL</span>
        <span className="block text-[10px] tracking-normal text-muted-foreground">Quranic Universal Library</span>
      </span>
    </span>
  )
}

/* ---------------- SearchInput ---------------- */

export interface SearchInputProps extends Omit<React.ComponentProps<'input'>, 'size'> {
  /** Keycap hint, e.g. "⌘K" */
  shortcut?: string
  size?: 'default' | 'lg'
}

function SearchInput({ shortcut, size = 'default', className, ...props }: SearchInputProps) {
  return (
    <label
      className={cn(
        'flex items-center gap-2 rounded-lg border bg-card px-3 text-muted-foreground shadow-xs transition-[box-shadow,border-color] focus-within:border-foreground/30 focus-within:ring-[3px] focus-within:ring-ring/30',
        size === 'default' ? 'h-9 text-sm' : 'h-12 px-4 text-base',
        className,
      )}
    >
      <SearchIcon className={size === 'lg' ? 'size-5' : 'size-4'} />
      <input
        type="search"
        className="min-w-0 flex-1 bg-transparent text-foreground outline-none placeholder:text-muted-foreground [&::-webkit-search-cancel-button]:hidden"
        {...props}
      />
      {shortcut && <Kbd>{shortcut}</Kbd>}
    </label>
  )
}

/* ---------------- Account ---------------- */

// Sign-out is a plain form post (DELETE through _method): Devise then redirects to an old page,
// which an Inertia visit could not show.
function SignOutForm({ ref, children, ...props }: React.ComponentProps<'form'>) {
  const signOut = destroyUserSession()
  return (
    <form ref={ref} method="post" action={signOut.url} onSubmit={fillAuthenticityToken} {...props}>
      <input type="hidden" name="_method" value={signOut.method} />
      <input type="hidden" name="authenticity_token" />
      {children}
    </form>
  )
}

function Initials({ user, className }: { user: AuthUser; className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold text-foreground',
        className,
      )}
    >
      {user.initials}
    </span>
  )
}

// Sign-in returns to the page it was opened from (Users::SessionsController stores the path).
function signInUrl(url: string) {
  return newUserSession({ query: { user_return_to: url } }).url
}

/** The signed-in user's initials and name, with a menu to sign out. */
function AccountMenu({ user }: { user: AuthUser }) {
  const formRef = React.useRef<HTMLFormElement>(null)
  return (
    <>
      <DropdownPrimitive.Root modal={false}>
        <DropdownPrimitive.Trigger asChild>
          <button
            type="button"
            className="flex h-9 items-center gap-2 rounded-full ps-0.5 pe-2.5 text-sm outline-none hover:bg-foreground/[0.05] focus-visible:ring-[3px] focus-visible:ring-ring/50"
          >
            <Initials user={user} />
            <span className="max-w-32 truncate font-medium">{user.name}</span>
          </button>
        </DropdownPrimitive.Trigger>
        <DropdownPrimitive.Portal>
          <DropdownPrimitive.Content
            align="end"
            sideOffset={8}
            className="z-50 min-w-48 rounded-xl border bg-popover p-1.5 text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          >
            <DropdownPrimitive.Label className="truncate px-2.5 py-2 text-sm font-medium">
              {user.name}
            </DropdownPrimitive.Label>
            <DropdownPrimitive.Separator className="my-1 h-px bg-border" />
            <DropdownPrimitive.Item
              onSelect={() => formRef.current?.requestSubmit()}
              className="flex cursor-pointer items-center gap-2 rounded-md px-2.5 py-2 text-sm outline-none data-[highlighted]:bg-foreground/[0.05] [&_svg]:size-4"
            >
              <LogOutIcon /> Sign out
            </DropdownPrimitive.Item>
          </DropdownPrimitive.Content>
        </DropdownPrimitive.Portal>
      </DropdownPrimitive.Root>
      <SignOutForm ref={formRef} className="hidden" aria-hidden="true" />
    </>
  )
}

/* ---------------- SiteHeader ---------------- */

export interface SiteHeaderProps {
  className?: string
}

/**
 * Global header of the new pages. Sticky, translucent over content. From lg up: the mega menu.
 * Below lg: a Menu button opens a sheet with the same sections and the account control. The
 * search button (and ⌘K / Ctrl K) opens the spotlight; the theme toggle is in the footer.
 */
function SiteHeader({ className }: SiteHeaderProps) {
  const { url, props } = usePage()
  const { auth, nav } = props
  const [menuOpen, setMenuOpen] = React.useState(false)
  const [searchOpen, setSearchOpen] = React.useState(false)
  // Set by the sheet's search field: the spotlight opens once the sheet has closed and given
  // focus back, so the two dialogs never fight over focus.
  const searchAfterMenu = React.useRef(false)
  const closeMenu = React.useCallback(() => setMenuOpen(false), [])
  React.useEffect(() => router.on('start', closeMenu), [closeMenu])

  return (
    <header className={cn('sticky top-0 z-40 border-b bg-background/85 backdrop-blur-md', className)}>
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-4 px-4 sm:px-6 2xl:gap-6">
        <NavAnchor link={nav.home} className="shrink-0 rounded-md text-foreground" aria-label="QUL home">
          <Logo variant="mark" />
        </NavAnchor>
        <MegaMenu menus={nav.menus} url={url} className="hidden lg:flex" />
        <div className="ms-auto flex items-center gap-1.5">
          <Spotlight open={searchOpen} onOpenChange={setSearchOpen} />
          <Button variant="ghost" size="icon-sm" asChild className="hidden sm:inline-flex">
            <a href={REPO_URL} target="_blank" rel="noreferrer" aria-label="QUL on GitHub">
              <GitHubMark />
            </a>
          </Button>
          <div className="hidden lg:flex">
            {auth.user ? (
              <AccountMenu user={auth.user} />
            ) : (
              <Button size="sm" asChild>
                <a href={signInUrl(url)}>Sign in</a>
              </Button>
            )}
          </div>
          <Dialog open={menuOpen} onOpenChange={setMenuOpen}>
            <DialogTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="lg:hidden" aria-label="Menu">
                <MenuIcon />
              </Button>
            </DialogTrigger>
            <DialogContent
              side="right"
              aria-describedby={undefined}
              className="max-w-none gap-0 p-0 sm:max-w-sm"
              onCloseAutoFocus={(event) => {
                if (!searchAfterMenu.current) return
                searchAfterMenu.current = false
                event.preventDefault()
                setSearchOpen(true)
              }}
            >
              <DialogTitle className="sr-only">Menu</DialogTitle>
              <div className="flex h-16 shrink-0 items-center px-5">
                <NavAnchor link={nav.home} className="text-foreground" aria-label="QUL home">
                  <Logo />
                </NavAnchor>
              </div>
              <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto overscroll-contain px-5 pb-6">
                <button
                  type="button"
                  onClick={() => {
                    searchAfterMenu.current = true
                    setMenuOpen(false)
                  }}
                  className="flex h-11 shrink-0 items-center gap-2 rounded-lg border bg-card px-3 text-base text-muted-foreground shadow-xs outline-none focus-visible:border-foreground/30 focus-visible:ring-[3px] focus-visible:ring-ring/30"
                >
                  <SearchIcon className="size-4" />
                  Search resources
                </button>
                <MobileNav menus={nav.menus} url={url} onNavigate={closeMenu} />
              </div>
              <div className="flex shrink-0 items-center gap-3 border-t bg-popover px-5 pt-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
                {auth.user ? (
                  <>
                    <Initials user={auth.user} className="size-9" />
                    <span className="min-w-0 flex-1 truncate text-sm font-medium">{auth.user.name}</span>
                    <SignOutForm>
                      <Button type="submit" variant="outline">
                        <LogOutIcon /> Sign out
                      </Button>
                    </SignOutForm>
                  </>
                ) : (
                  <Button size="lg" asChild className="flex-1">
                    <a href={signInUrl(url)}>Sign in</a>
                  </Button>
                )}
              </div>
            </DialogContent>
          </Dialog>
        </div>
      </div>
    </header>
  )
}

/* ---------------- SiteFooter ---------------- */

function FooterColumn({ group }: { group: SiteNavGroup }) {
  return (
    <div>
      <p className="mb-3 text-sm font-medium">{group.heading}</p>
      <ul className="flex flex-col gap-2 text-sm text-muted-foreground">
        {group.links.map((link) => (
          <li key={link.label}>
            <NavAnchor link={link} className="inline-flex items-center gap-1 hover:text-foreground">
              {link.label}
              {link.external && <ArrowUpRightIcon className="size-3" />}
            </NavAnchor>
          </li>
        ))}
      </ul>
    </div>
  )
}

/** Global footer: the mark, link columns and a bottom bar with the theme toggle. */
function SiteFooter({ className }: { className?: string }) {
  const { nav } = usePage().props
  return (
    <footer className={cn('mt-16 border-t bg-surface', className)}>
      <div className="mx-auto grid max-w-7xl grid-cols-2 gap-x-6 gap-y-10 px-4 py-12 sm:px-6 md:grid-cols-4 lg:grid-cols-[1.5fr_repeat(4,1fr)]">
        <div className="col-span-2 flex flex-col gap-4 md:col-span-4 lg:col-span-1">
          <Logo variant="mark" />
          <p className="max-w-xs text-sm text-muted-foreground">
            Quranic Universal Library. Open, checked Quran data and tools, free for anyone who builds for the Quran.
          </p>
        </div>
        {nav.footer.map((group) => (
          <FooterColumn key={group.heading} group={group} />
        ))}
      </div>
      <div className="border-t">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-x-6 gap-y-2 px-4 py-3 text-xs text-muted-foreground sm:px-6">
          <span>Quranic Universal Library, by Tarteel and contributors.</span>
          <ThemeToggle />
        </div>
      </div>
    </footer>
  )
}

export { Logo, SearchInput, SiteHeader, SiteFooter }

import type { ReactElement } from 'react'

import * as layout from '@/components/layout'
import * as chrome from '@/components/qul/chrome'
import * as flash from '@/components/qul/flash'
import * as icons from '@/components/qul/icons'
import * as nav from '@/components/qul/nav'
import * as pageHeader from '@/components/qul/page-header'
import * as resourceCard from '@/components/qul/resource-card'
import * as theme from '@/components/qul/theme'
import * as badge from '@/components/ui/badge'
import * as button from '@/components/ui/button'
import * as card from '@/components/ui/card'
import * as drawer from '@/components/ui/drawer'
import * as input from '@/components/ui/input'
import * as misc from '@/components/ui/misc'
import * as overlays from '@/components/ui/overlays'
import * as tabs from '@/components/ui/tabs'

import { nav as navProps } from './shell'

const modules = {
  layout,
  chrome,
  flash,
  icons,
  nav,
  pageHeader,
  resourceCard,
  theme,
  badge,
  button,
  card,
  drawer,
  input,
  misc,
  overlays,
  tabs,
}

// Every component the kit exports: the capitalised exports of its modules (helpers such as
// buttonVariants and isMenuActive are lower case).
export const componentNames = Object.values(modules)
  .flatMap((module) => Object.keys(module))
  .filter((name) => /^[A-Z]/.test(name))
  .sort()

const { Container, SiteShell } = layout
const { Logo, SearchInput, SiteFooter, SiteHeader } = chrome
const { FlashMessages } = flash
const { GitHubMark, QulIcon, ResourceIcon } = icons
const { MegaMenu, MobileNav, NavAnchor } = nav
const { PageHeader } = pageHeader
const { ResourceCard } = resourceCard
const { ThemeToggle } = theme
const { Badge } = badge
const { Button } = button
const { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } = card
const {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} = drawer
const { Input, Label, Textarea } = input
const { Checkbox, Kbd, Separator, Skeleton, Table, TableBody, TableCell, TableHead, TableHeader, TableRow } = misc
const {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} = overlays
const { Tabs, TabsContent, TabsList, TabsTrigger } = tabs

const table = (
  <Table>
    <TableHeader>
      <TableRow>
        <TableHead>Name</TableHead>
      </TableRow>
    </TableHeader>
    <TableBody>
      <TableRow>
        <TableCell>Sahih International</TableCell>
      </TableRow>
    </TableBody>
  </Table>
)

const cardElement = (
  <Card>
    <CardHeader>
      <CardTitle>Card title</CardTitle>
      <CardDescription>Card description</CardDescription>
      <CardAction>Action</CardAction>
    </CardHeader>
    <CardContent>Card content</CardContent>
    <CardFooter>Card footer</CardFooter>
  </Card>
)

const dialog = (
  <Dialog defaultOpen>
    <DialogTrigger>Open the dialog</DialogTrigger>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Dialog title</DialogTitle>
        <DialogDescription>Dialog description</DialogDescription>
      </DialogHeader>
      <DialogFooter>
        <DialogClose>Close</DialogClose>
      </DialogFooter>
    </DialogContent>
  </Dialog>
)

const drawerElement = (
  <Drawer defaultOpen>
    <DrawerTrigger>Open the drawer</DrawerTrigger>
    <DrawerContent>
      <DrawerHeader>
        <DrawerTitle>Drawer title</DrawerTitle>
        <DrawerDescription>Drawer description</DrawerDescription>
      </DrawerHeader>
      <DrawerFooter>
        <DrawerClose>Close</DrawerClose>
      </DrawerFooter>
    </DrawerContent>
  </Drawer>
)

const tooltip = (
  <TooltipProvider>
    <Tooltip defaultOpen>
      <TooltipTrigger>Hover me</TooltipTrigger>
      <TooltipContent>Tooltip text</TooltipContent>
    </Tooltip>
  </TooltipProvider>
)

const tabsElement = (
  <Tabs defaultValue="preview">
    <TabsList variant="line">
      <TabsTrigger value="preview">Preview</TabsTrigger>
      <TabsTrigger value="data">Data</TabsTrigger>
    </TabsList>
    <TabsContent value="preview">Preview tab</TabsContent>
    <TabsContent value="data">Data tab</TabsContent>
  </Tabs>
)

// One rendering of each exported component, with the text the render tests look for. A
// component that only works inside another one (CardTitle, DialogContent) is shown in it.
// `text` is in the server HTML; `openText` is in a portal (an open dialog, drawer or tooltip),
// which mounts in the browser only, after hydration.
export const fixtures: Record<string, { element: ReactElement; text: string; openText?: string }> = {
  Container: { element: <Container>Contained</Container>, text: 'Contained' },
  SiteShell: { element: <SiteShell>Page body</SiteShell>, text: 'Page body' },
  Logo: { element: <Logo />, text: 'Quranic Universal Library' },
  SearchInput: { element: <SearchInput placeholder="Search" shortcut="⌘K" />, text: '⌘K' },
  SiteHeader: { element: <SiteHeader />, text: 'Resources' },
  SiteFooter: { element: <SiteFooter />, text: 'All docs' },
  FlashMessages: { element: <FlashMessages />, text: 'Signed in successfully.' },
  GitHubMark: { element: <GitHubMark />, text: '<svg' },
  QulIcon: { element: <QulIcon name="bundle" />, text: '<svg' },
  ResourceIcon: { element: <ResourceIcon category="audio" />, text: 'text-cat-audio' },
  MegaMenu: { element: <MegaMenu menus={navProps.menus} url="/resources" />, text: 'Contribute' },
  MobileNav: { element: <MobileNav menus={navProps.menus} url="/resources" />, text: 'Contribute' },
  NavAnchor: { element: <NavAnchor link={navProps.search}>Search</NavAnchor>, text: 'href="/resources"' },
  PageHeader: {
    element: <PageHeader breadcrumb={[{ label: 'Resources', href: '/resources' }, { label: 'Fonts' }]} title="Fonts" />,
    text: 'Fonts',
  },
  ResourceCard: {
    element: <ResourceCard title="Sahih International" href="/resources/translation/1" facts={['Translation']} />,
    text: 'Sahih International',
  },
  ThemeToggle: { element: <ThemeToggle />, text: 'theme' },
  Badge: { element: <Badge variant="brand">Recommended</Badge>, text: 'Recommended' },
  Button: { element: <Button variant="outline">Download</Button>, text: 'Download' },
  Card: { element: cardElement, text: 'Card content' },
  CardHeader: { element: cardElement, text: 'Card title' },
  CardTitle: { element: cardElement, text: 'Card title' },
  CardDescription: { element: cardElement, text: 'Card description' },
  CardAction: { element: cardElement, text: 'Action' },
  CardContent: { element: cardElement, text: 'Card content' },
  CardFooter: { element: cardElement, text: 'Card footer' },
  Drawer: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerTrigger: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerContent: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerHeader: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerTitle: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerDescription: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerFooter: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  DrawerClose: { element: drawerElement, text: 'Open the drawer', openText: 'Drawer description' },
  Input: { element: <Input defaultValue="Urdu" />, text: 'Urdu' },
  Textarea: { element: <Textarea defaultValue="A note" />, text: 'A note' },
  Label: { element: <Label>Language</Label>, text: 'Language' },
  Separator: { element: <Separator />, text: 'data-orientation="horizontal"' },
  Skeleton: { element: <Skeleton />, text: 'animate-pulse' },
  Checkbox: { element: <Checkbox defaultChecked aria-label="Madani" />, text: 'Madani' },
  Kbd: { element: <Kbd>⌘K</Kbd>, text: '⌘K' },
  Table: { element: table, text: 'Sahih International' },
  TableHeader: { element: table, text: 'Name' },
  TableBody: { element: table, text: 'Sahih International' },
  TableRow: { element: table, text: 'Sahih International' },
  TableHead: { element: table, text: 'Name' },
  TableCell: { element: table, text: 'Sahih International' },
  Dialog: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogTrigger: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogContent: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogHeader: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogTitle: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogDescription: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogFooter: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  DialogClose: { element: dialog, text: 'Open the dialog', openText: 'Dialog description' },
  Tooltip: { element: tooltip, text: 'Hover me', openText: 'Tooltip text' },
  TooltipProvider: { element: tooltip, text: 'Hover me', openText: 'Tooltip text' },
  TooltipTrigger: { element: tooltip, text: 'Hover me', openText: 'Tooltip text' },
  TooltipContent: { element: tooltip, text: 'Hover me', openText: 'Tooltip text' },
  Tabs: { element: tabsElement, text: 'Preview tab' },
  TabsList: { element: tabsElement, text: 'Data' },
  TabsTrigger: { element: tabsElement, text: 'Data' },
  TabsContent: { element: tabsElement, text: 'Preview tab' },
}

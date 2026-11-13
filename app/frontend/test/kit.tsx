import type { ReactElement } from 'react'

import * as layout from '@/components/layout'
import * as cardPreview from '@/components/previews/card-preview'
import * as appIcon from '@/components/qul/app-icon'
import * as appSubmission from '@/components/qul/app-submission'
import * as bundle from '@/components/qul/bundle'
import * as catalog from '@/components/qul/catalog'
import * as chrome from '@/components/qul/chrome'
import * as copyButton from '@/components/qul/copy-button'
import * as data from '@/components/qul/data'
import * as docs from '@/components/qul/docs'
import * as downloadPanel from '@/components/qul/download-panel'
import * as flash from '@/components/qul/flash'
import * as gatedForm from '@/components/qul/gated-form'
import * as icons from '@/components/qul/icons'
import * as nav from '@/components/qul/nav'
import * as pageHeader from '@/components/qul/page-header'
import * as resourceCard from '@/components/qul/resource-card'
import * as shardRing from '@/components/qul/shard-ring'
import * as spotlight from '@/components/qul/spotlight'
import * as start from '@/components/qul/start'
import * as statusBadge from '@/components/qul/status-badge'
import * as theme from '@/components/qul/theme'
import * as toolCard from '@/components/qul/tool-card'
import * as badge from '@/components/ui/badge'
import * as button from '@/components/ui/button'
import * as card from '@/components/ui/card'
import * as drawer from '@/components/ui/drawer'
import * as input from '@/components/ui/input'
import * as misc from '@/components/ui/misc'
import * as overlays from '@/components/ui/overlays'
import * as tabs from '@/components/ui/tabs'

import { catalogPageProps, resourcePageProps } from './catalog'
import { docsNavigation, tutorialDoc } from './content'
import { appsPageProps, homePageProps } from './site'
import { nav as navProps } from './shell'
import { kitCard as kitCardProps } from './start'

const modules = {
  layout,
  cardPreview,
  appIcon,
  appSubmission,
  bundle,
  catalog,
  chrome,
  copyButton,
  data,
  docs,
  downloadPanel,
  flash,
  gatedForm,
  icons,
  nav,
  pageHeader,
  resourceCard,
  shardRing,
  spotlight,
  start,
  statusBadge,
  theme,
  toolCard,
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
const { CardPreview } = cardPreview
const { AppIcon } = appIcon
const { AppSubmissionDialog } = appSubmission
const { AddToBundle, BundleToggle, BundleTray } = bundle
const { ShardRing } = shardRing
const { EmptyState, FacetGroup, FilterChip, RequestCard } = catalog
const { Logo, SearchInput, SiteFooter, SiteHeader } = chrome
const { CopyButton } = copyButton
const { SchemaTable } = data
const { CodeBlock, DocBody, DocContents, DocsLayout, DocsNav, Playground } = docs
const { DownloadPanel, WorksWith } = downloadPanel
const { FlashMessages } = flash
const { GatedForm } = gatedForm
const { GoalCard, GoalIcon, KitCard, ResultCard } = start
const { GitHubMark, QulIcon, ResourceIcon } = icons
const { MegaMenu, MobileNav, NavAnchor } = nav
const { PageHeader } = pageHeader
const { ResourceCard } = resourceCard
const { Spotlight } = spotlight
const { RecommendedBadge, StatusBadge } = statusBadge
const { ToolCard } = toolCard
const { ThemeSwitch } = theme
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
  DownloadPanel: {
    element: (
      <DownloadPanel
        id={1}
        type="tafsir"
        slug="tafsir-ibn-kathir"
        files={resourcePageProps.files}
        canDownload
        restriction={null}
        downloadMode="sign_in"
        signInHref="/users/sign_in"
      />
    ),
    text: '5.1 MB',
  },
  DocBody: { element: <DocBody segments={tutorialDoc.segments} />, text: 'What you will build' },
  CodeBlock: { element: <CodeBlock label="Shell" code="bin/rails server" />, text: 'bin/rails server' },
  Playground: { element: <Playground code="console.log(1)" />, text: 'console.log(1)' },
  DocContents: { element: <DocContents contents={tutorialDoc.contents} />, text: 'Run the example' },
  DocsNav: { element: <DocsNav navigation={docsNavigation} current="datasets" />, text: 'aria-current="page"' },
  DocsLayout: {
    element: (
      <DocsLayout navigation={docsNavigation} current="datasets" trail={['Download Resources', 'Datasets']}>
        Page body
      </DocsLayout>
    ),
    text: 'Page body',
  },
  CopyButton: { element: <CopyButton text={() => 'copied'} label="Copy link" />, text: 'aria-label="Copy link"' },
  SchemaTable: { element: <SchemaTable schema={resourcePageProps.schemas[0]} />, text: 'the ayah this row is for.' },
  WorksWith: { element: <WorksWith groups={resourcePageProps.worksWith} />, text: 'not yet reviewed' },
  AppIcon: { element: <AppIcon app={homePageProps.showcase[3]} />, text: 'QV' },
  ShardRing: { element: <ShardRing className="h-64" />, text: 'data-motion' },
  GitHubMark: { element: <GitHubMark />, text: '<svg' },
  QulIcon: { element: <QulIcon name="bundle" />, text: '<svg' },
  ResourceIcon: { element: <ResourceIcon category="audio" />, text: 'text-cat-audio' },
  MegaMenu: { element: <MegaMenu menus={navProps.menus} url="/resources" />, text: 'Contribute' },
  MobileNav: { element: <MobileNav menus={navProps.menus} url="/resources" />, text: 'Contribute' },
  NavAnchor: { element: <NavAnchor link={navProps.search}>Search</NavAnchor>, text: 'href="/resources"' },
  PageHeader: {
    element: (
      <PageHeader
        breadcrumb={[{ label: 'Resources', href: '/resources' }, { label: 'Fonts' }]}
        icon={<ResourceIcon category="script" size="xl" />}
        title="Fonts"
        actions={
          <Button variant="outline" asChild>
            <a href="/docs/resource-fonts">Font format docs</a>
          </Button>
        }
      />
    ),
    text: 'Font format docs',
  },
  ResourceCard: {
    element: (
      <ResourceCard
        title="Sahih International"
        bundleId={1}
        href="/resources/translation/1"
        category="translation"
        facts={['Translation']}
        summary="English translation of the Quran, ayah by ayah."
        formats={['JSON', 'SQLite']}
        preview={<CardPreview kind="text" url="/resources/translation/1/preview" />}
      />
    ),
    text: 'JSON · SQLite',
  },
  BundleToggle: {
    element: <BundleToggle id={1} name="Sahih International" />,
    text: 'Add Sahih International to bundle',
  },
  AddToBundle: { element: <AddToBundle ids={[1, 2]} label="Add kit to bundle" />, text: 'Add kit to bundle' },
  BundleTray: { element: <BundleTray />, text: 'Bundle, 0 resources' },
  ResultCard: {
    element: <ResultCard result={catalogPageProps.results[0]} vocabularies={catalogPageProps.vocabularies} />,
    text: 'Sahih International',
  },
  GoalCard: { element: <GoalCard goal={homePageProps.goals[0]} href="/start?goal=reader" />, text: 'Quran reader app' },
  GoalIcon: { element: <GoalIcon goal="audio" />, text: '<svg' },
  KitCard: { element: <KitCard kit={kitCardProps} />, text: 'View kit' },
  CardPreview: {
    element: <CardPreview kind="font" url="/resources/font/qpc-hafs/preview" />,
    text: 'data-state="waiting"',
  },
  StatusBadge: {
    element: (
      <StatusBadge
        status="superseded"
        label="Superseded"
        supersededBy={{ name: 'Syllables Transliteration', href: '/resources/transliteration/syllables' }}
      />
    ),
    text: 'Syllables Transliteration',
  },
  ToolCard: {
    element: (
      <ToolCard
        tool={{
          label: 'Ayah audio segments',
          href: '/segments/ayah',
          description: 'Word timestamps, ayah by ayah.',
          category: 'audio',
          icon: 'timer',
          external: false,
          inertia: false,
        }}
      />
    ),
    text: 'Word timestamps, ayah by ayah.',
  },
  RecommendedBadge: { element: <RecommendedBadge reviewed={false} />, text: 'not yet reviewed' },
  ThemeSwitch: { element: <ThemeSwitch />, text: 'System theme' },
  Spotlight: { element: <Spotlight open={false} onOpenChange={() => {}} />, text: 'Search resources' },
  FacetGroup: {
    element: (
      <FacetGroup
        title="Language"
        limit={1}
        onToggle={() => {}}
        options={[
          { value: 'en', label: 'English', count: 12, checked: false },
          { value: 'ur', label: 'Urdu', count: 4, checked: false },
        ]}
      />
    ),
    text: 'English',
  },
  EmptyState: { element: <EmptyState title="Nothing matches this search" />, text: 'Nothing matches this search' },
  FilterChip: {
    element: <FilterChip option={{ key: 'ios', label: 'iOS' }} selected onClick={() => {}} />,
    text: 'aria-pressed="true"',
  },
  GatedForm: {
    element: (
      <GatedForm returnTo="/apps?submit=1" purpose="submit your app">
        <Input aria-label="App name" />
      </GatedForm>
    ),
    text: 'user_return_to=%2Fapps%3Fsubmit%3D1',
  },
  AppSubmissionDialog: {
    element: (
      <AppSubmissionDialog
        open
        onOpenChange={() => {}}
        platforms={appsPageProps.platforms}
        types={appsPageProps.submissionTypes}
      />
    ),
    text: '',
    openText: 'Which QUL resources does it use?',
  },
  RequestCard: { element: <RequestCard link={navProps.request} />, text: 'resource_request.yml' },
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

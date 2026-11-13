import { Link } from '@inertiajs/react'
import { ArrowRightIcon } from 'lucide-react'

import { CardPreview } from '@/components/previews/card-preview'
import { catalogResourcePreview, detailResources } from '@/routes'
import type {
  CatalogOption,
  CatalogSearchResult,
  CatalogVocabularies,
  StartGoal,
  StartKitCard,
} from '@/types/serializers'

import { QulIcon, ResourceIcon, type IconName } from './icons'
import { ResourceCard } from './resource-card'
import { StatusBadge } from './status-badge'

// The pieces of the guided setup and the starter kits, shared by the home page and the start
// pages. They are one module, so the catalog's entry names one chunk for them.

/* ---------------- goals ---------------- */

// The glyph of each goal of the guided setup (GuidedSetup::GOALS).
const GOAL_ICONS: Record<string, IconName> = {
  reader: 'reader',
  audio: 'audio-goal',
  study: 'study',
  learning: 'learning',
  research: 'research',
  print: 'print',
}

export function GoalIcon({ goal }: { goal: string }) {
  return (
    <span className="flex size-10 items-center justify-center rounded-lg bg-secondary">
      <QulIcon name={GOAL_ICONS[goal] ?? 'reader'} size={22} />
    </span>
  )
}

// A goal of the guided setup that opens the setup with it answered (the home page's "What are
// you building?"). From the v8 design (ds/src/components/qul/cards.tsx, GoalCard).
export function GoalCard({ goal, href }: { goal: StartGoal; href: string }) {
  return (
    <Link
      href={href}
      className="flex h-full flex-col gap-4 rounded-xl bg-card p-5 text-left shadow-xs transition-shadow outline-none hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50"
    >
      <GoalIcon goal={goal.key} />
      <span>
        <span className="block text-lg font-medium tracking-tight">{goal.label}</span>
        <span className="mt-1 block text-sm text-muted-foreground">{goal.blurb}</span>
      </span>
    </Link>
  )
}

/* ---------------- kits ---------------- */

// A starter kit on the home page's "Start from a kit" row and the kits index: what it is for and
// the resources in it, linking to its page. From the v8 design (ds/src/app/pages/home.tsx, Kits);
// the resources are named instead of the files of a zip, which the kits do not have.
export function KitCard({ kit }: { kit: StartKitCard }) {
  return (
    <Link
      href={kit.path}
      className="group flex h-full flex-col gap-4 rounded-xl bg-card p-5 shadow-xs transition-shadow outline-none hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50"
    >
      <span className="text-xs text-muted-foreground">{kit.tag}</span>
      <span>
        <span className="block text-xl font-medium tracking-tight">{kit.title}</span>
        <span className="mt-1 block text-sm text-muted-foreground">{kit.blurb}</span>
      </span>
      <ul aria-label={`In ${kit.title}`} className="flex flex-col gap-2 border-t pt-4 text-sm">
        {kit.resources.map((resource) => (
          <li key={resource.name} className="flex min-w-0 items-center gap-2">
            <ResourceIcon category={resource.category} variant="plain" size="sm" />
            <span className="truncate">{resource.name}</span>
          </li>
        ))}
      </ul>
      <span className="mt-auto inline-flex items-center gap-1 text-sm font-medium">
        View kit <ArrowRightIcon className="size-4 transition-transform group-hover:translate-x-0.5" />
      </span>
    </Link>
  )
}

/* ---------------- catalog results ---------------- */

function labelOf(options: CatalogOption[], key: string) {
  return options.find((option) => option.key === key)?.label ?? key
}

export interface ResultCardProps {
  result: CatalogSearchResult
  vocabularies: Pick<CatalogVocabularies, 'types' | 'granularities' | 'statuses' | 'formats'>
  /** `compact` is a list row with no preview or summary (ResourceCard) */
  density?: 'default' | 'compact'
  /** Whether a new page serves the detail page */
  inertia?: boolean
  className?: string
}

// A catalog search result as a ResourceCard, for pages outside the catalog (the guided setup's
// results, the kit pages). The catalog renders its own, so this file stays out of its bundle.
export function ResultCard({ result, vocabularies, density, inertia, className }: ResultCardProps) {
  return (
    <ResourceCard
      className={className}
      density={density}
      inertia={inertia}
      title={result.name}
      href={detailResources({ type: result.type, id: result.toParam }).url}
      category={vocabularies.types.find((option) => option.key === result.type)?.category.key ?? 'metadata'}
      facts={[
        labelOf(vocabularies.types, result.type),
        result.language,
        result.granularity && labelOf(vocabularies.granularities, result.granularity),
      ].filter((fact): fact is string => Boolean(fact))}
      summary={result.summary}
      status={
        result.status !== 'stable' && (
          <StatusBadge status={result.status} label={labelOf(vocabularies.statuses, result.status)} />
        )
      }
      formats={result.formats.map((format) => labelOf(vocabularies.formats, format))}
      muted={result.status === 'legacy' || result.status === 'superseded'}
      preview={
        density !== 'compact' &&
        result.previewKind && (
          <CardPreview
            kind={result.previewKind}
            url={catalogResourcePreview({ type: result.type, slug: result.toParam }).url}
          />
        )
      }
    />
  )
}

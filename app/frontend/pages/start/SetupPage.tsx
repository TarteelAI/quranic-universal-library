import { Link, router } from '@inertiajs/react'
import { ArrowLeftIcon, ArrowRightIcon, CheckIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { CardPreview } from '@/components/previews/card-preview'
import { FilterChip } from '@/components/qul/catalog'
import { SearchInput } from '@/components/qul/chrome'
import { GoalIcon } from '@/components/qul/start'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import { catalogResourcePreview, catalogResources, startSetup } from '@/routes'
import type { StartAnswers, StartSetupShow } from '@/types/serializers'

type Step = StartAnswers['answered'][number]
type Answers = Pick<StartAnswers, 'goals' | 'platforms' | 'features' | 'scripts' | 'languages'>

const STEPS: { key: Step; label: string }[] = [
  { key: 'goal', label: 'Goal' },
  { key: 'platform', label: 'Platforms' },
  { key: 'feature', label: 'Features' },
  { key: 'script', label: 'Script' },
  { key: 'lang', label: 'Languages' },
]
const VALUES: Record<Step, keyof Answers> = {
  goal: 'goals',
  platform: 'platforms',
  feature: 'features',
  script: 'scripts',
  lang: 'languages',
}
// Steps that need at least one pick before Continue.
const REQUIRED: Step[] = ['goal', 'script']

// The answers as the query GuidedSetup::Answers reads: one comma list per answered step.
function setupQuery(answers: Answers, steps: Step[]) {
  return STEPS.filter(({ key }) => steps.includes(key))
    .map(({ key }) => `${key}=${answers[VALUES[key]].join(',')}`)
    .join('&')
}

function toggle(list: string[], value: string) {
  return list.includes(value) ? list.filter((item) => item !== value) : [...list, value]
}

// /start: the guided setup, five questions on one page, one step at a time. The steps answered
// so far are in the URL (replaced as answers change), so a reload or a shared link resumes the
// setup; the server opens it at the first unanswered step. The last step links to the catalog
// filtered for the answers (Start::SetupController#results).
export default function SetupPage({
  goals,
  platforms,
  features,
  scripts,
  languages,
  answers: initial,
  catalogPages,
}: StartSetupShow) {
  const [step, setStep] = React.useState(initial.step)
  const [answered, setAnswered] = React.useState<Step[]>(initial.answered)
  const [answers, setAnswers] = React.useState<Answers>(() => ({
    ...initial,
    features: initial.answered.includes('feature') ? initial.features : featuresFor(initial.goals),
  }))
  const [languageQuery, setLanguageQuery] = React.useState('')

  function featuresFor(keys: string[]) {
    const wanted = new Set(goals.filter((goal) => keys.includes(goal.key)).flatMap((goal) => goal.features))
    return features.filter((feature) => wanted.has(feature.key)).map((feature) => feature.key)
  }

  const query = setupQuery(answers, answered)
  React.useEffect(() => {
    const url = query ? `${startSetup.show().url}?${query}` : startSetup.show().url
    if (url !== window.location.pathname + window.location.search)
      router.replace({ url, preserveState: true, preserveScroll: true })
  }, [query])

  const current = STEPS[step].key
  const set = (key: keyof Answers, values: string[]) => setAnswers((before) => ({ ...before, [key]: values }))
  const toggleGoal = (key: string) => {
    const next = toggle(answers.goals, key)
    // Until the features step is answered, the features follow the goals.
    setAnswers((before) => ({
      ...before,
      goals: next,
      features: answered.includes('feature') ? before.features : featuresFor(next),
    }))
  }
  const canContinue = !REQUIRED.includes(current) || answers[VALUES[current]].length > 0
  const next = () => {
    setAnswered((before) => (before.includes(current) ? before : [...before, current]))
    setStep(step + 1)
  }
  const last = step === STEPS.length - 1
  const resultsQuery = setupQuery(
    answers,
    STEPS.map(({ key }) => key),
  )
  const browseHref = catalogResources.index().url
  const shownLanguages = languages.filter((language) =>
    language.name.toLowerCase().includes(languageQuery.trim().toLowerCase()),
  )

  return (
    <SiteShell>
      <Container className="flex flex-col gap-5 pt-10 pb-2">
        <div className="flex items-center justify-between gap-4">
          <p className="text-sm text-muted-foreground">{`Step ${step + 1} of ${STEPS.length}`}</p>
          {catalogPages ? (
            <Link href={browseHref} className="text-sm text-muted-foreground hover:text-foreground">
              Skip and browse everything
            </Link>
          ) : (
            <a href={browseHref} className="text-sm text-muted-foreground hover:text-foreground">
              Skip and browse everything
            </a>
          )}
        </div>
        <StepProgress current={step} onStepClick={setStep} />
      </Container>

      <Container className="max-w-4xl py-12">
        {current === 'goal' && (
          <StepBody title="What are you building?" text="Pick one or more. Your goal sets the features on step 3.">
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {goals.map((goal) => (
                <Tile
                  key={goal.key}
                  selected={answers.goals.includes(goal.key)}
                  onClick={() => toggleGoal(goal.key)}
                  title={
                    <>
                      <GoalIcon goal={goal.key} />
                      <span>
                        <span className="block text-lg font-medium tracking-tight">{goal.label}</span>
                        <span className="mt-1 block text-sm text-muted-foreground">{goal.blurb}</span>
                      </span>
                    </>
                  }
                />
              ))}
            </div>
          </StepBody>
        )}

        {current === 'platform' && (
          <StepBody
            title="Where will it run?"
            text="This sets the file formats we point you to: SQLite for phones, JSON for the web, CSV for data work. Pick none to see every format."
          >
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {platforms.map((platform) => (
                <Tile
                  key={platform.key}
                  selected={answers.platforms.includes(platform.key)}
                  onClick={() => set('platforms', toggle(answers.platforms, platform.key))}
                  title={
                    <span>
                      <span className="block font-medium">{platform.label}</span>
                      <span className="block text-sm text-muted-foreground">{platform.hint}</span>
                    </span>
                  }
                />
              ))}
            </div>
          </StepBody>
        )}

        {current === 'feature' && (
          <StepBody title="Which features do you need?" text="Selected from your goal. Add or remove any.">
            <div role="group" aria-label="Features" className="flex flex-wrap gap-2">
              {features.map((feature) => (
                <FilterChip
                  key={feature.key}
                  option={feature}
                  selected={answers.features.includes(feature.key)}
                  onClick={() => {
                    set('features', toggle(answers.features, feature.key))
                    setAnswered((before) => (before.includes('feature') ? before : [...before, 'feature']))
                  }}
                  className="h-10 px-4"
                />
              ))}
            </div>
          </StepBody>
        )}

        {current === 'script' && (
          <StepBody
            title="Which script do your users read?"
            text="This sets the Quran text, the font and the page layout. Pick one or both."
          >
            <div className="grid gap-4 md:grid-cols-2">
              {scripts.map((script) => (
                <Tile
                  key={script.key}
                  selected={answers.scripts.includes(script.key)}
                  onClick={() => set('scripts', toggle(answers.scripts, script.key))}
                  title={<span className="text-lg font-medium tracking-tight">{script.label}</span>}
                >
                  {script.sample?.previewKind && (
                    <CardPreview
                      kind={script.sample.previewKind}
                      url={catalogResourcePreview({ type: script.sample.type, slug: script.sample.toParam }).url}
                    />
                  )}
                  <span className="text-sm text-muted-foreground">{script.blurb}</span>
                </Tile>
              ))}
            </div>
          </StepBody>
        )}

        {current === 'lang' && (
          <StepBody
            title="Which languages?"
            text="For translations, tafsir and word by word. The numbers show how many resources each language has."
          >
            <SearchInput
              aria-label="Search languages"
              placeholder={`Search ${languages.length} languages`}
              className="max-w-sm"
              value={languageQuery}
              onChange={(event) => setLanguageQuery(event.target.value)}
            />
            <div role="group" aria-label="Languages" className="flex flex-wrap gap-2">
              {shownLanguages.map((language) => (
                <FilterChip
                  key={language.key}
                  option={{ key: language.key, label: `${language.name} ${language.count}` }}
                  aria-label={language.name}
                  selected={answers.languages.includes(language.key)}
                  onClick={() => set('languages', toggle(answers.languages, language.key))}
                  className="h-10 px-4"
                />
              ))}
            </div>
            {shownLanguages.length === 0 && <p className="text-sm text-muted-foreground">No language matches.</p>}
          </StepBody>
        )}

        <div className="mt-12 flex items-center justify-between gap-3 border-t pt-6">
          <Button variant="ghost" onClick={() => setStep(step - 1)} disabled={step === 0}>
            <ArrowLeftIcon /> Back
          </Button>
          {!last ? (
            <Button size="lg" disabled={!canContinue} onClick={next}>
              Continue <ArrowRightIcon />
            </Button>
          ) : catalogPages ? (
            <Button size="lg" variant="brand" asChild>
              <Link href={`${catalogResources.index().url}?${resultsQuery}`}>
                Show matching resources <ArrowRightIcon />
              </Link>
            </Button>
          ) : (
            <Button size="lg" variant="brand" asChild>
              <a href={browseHref}>
                Browse resources <ArrowRightIcon />
              </a>
            </Button>
          )}
        </div>
      </Container>
    </SiteShell>
  )
}

function StepProgress({ current, onStepClick }: { current: number; onStepClick: (step: number) => void }) {
  return (
    <ol className="grid grid-cols-5 gap-2" aria-label="Progress">
      {STEPS.map(({ key, label }, index) => {
        const done = index < current
        const active = index === current
        return (
          <li key={key}>
            <button
              type="button"
              disabled={!done}
              aria-current={active ? 'step' : undefined}
              onClick={() => onStepClick(index)}
              aria-label={label}
              className="group flex w-full flex-col gap-2 text-left text-sm"
            >
              <span
                className={cn('h-1 w-full rounded-full bg-border', done && 'bg-brand', active && 'bg-foreground')}
              />
              <span
                className={cn(
                  'flex items-center gap-1.5 truncate',
                  active ? 'font-medium' : 'text-muted-foreground',
                  done && 'group-hover:text-foreground',
                )}
              >
                {done ? (
                  <CheckIcon className="size-3.5 shrink-0" strokeWidth={3} />
                ) : (
                  <span className="font-mono text-xs tabular-nums">{index + 1}</span>
                )}
                <span className={cn('truncate', !active && 'hidden sm:inline')}>{label}</span>
              </span>
            </button>
          </li>
        )
      })}
    </ol>
  )
}

function StepBody({ title, text, children }: { title: string; text: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="headline text-3xl sm:text-4xl">{title}</h1>
        <p className="mt-2 text-muted-foreground">{text}</p>
      </div>
      <div className="flex flex-col gap-4">{children}</div>
    </div>
  )
}

// A selectable tile: the title row ends in a round check, filled when selected, and a selected
// tile has an ink outline. `children` go below the title row.
function Tile({
  selected,
  onClick,
  title,
  children,
}: {
  selected: boolean
  onClick: () => void
  title: React.ReactNode
  children?: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      className={cn(
        'flex h-full flex-col gap-4 rounded-xl bg-card p-5 text-left shadow-xs transition-shadow outline-none hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50',
        selected && 'ring-1 ring-foreground',
      )}
    >
      <span className="flex w-full items-start justify-between gap-3">
        <span className="flex flex-col gap-3">{title}</span>
        <span
          className={cn(
            'flex size-5 shrink-0 items-center justify-center rounded-full border border-foreground/25',
            selected && 'border-brand bg-brand text-foreground',
          )}
        >
          {selected && <CheckIcon className="size-3" strokeWidth={3} />}
        </span>
      </span>
      {children}
    </button>
  )
}

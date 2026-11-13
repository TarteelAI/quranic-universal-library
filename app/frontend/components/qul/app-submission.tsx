import { useForm } from '@inertiajs/react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Input, Label } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/misc'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/overlays'
import { appsDirectory, appSubmissions } from '@/routes'
import type { CatalogOption } from '@/types/serializers'

import { FilterChip } from './catalog'
import { GatedForm } from './gated-form'

export interface AppSubmissionDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  platforms: CatalogOption[]
  types: CatalogOption[]
}

type Submission = {
  name: string
  url: string
  platforms: string[]
  uses: string[]
  contact: string
  consent: boolean
  icon: File | null
}

const toggled = (values: string[], value: string) =>
  values.includes(value) ? values.filter((item) => item !== value) : [...values, value]

/**
 * "Submit your app" on /apps, from the v8 design (ds/src/app/pages/apps.tsx) with an icon field.
 * Posts to POST /apps (Site::AppSubmissionsController) as an Inertia visit: the server answers
 * with the page it came from, and its validation errors show beside the fields. The fields keep
 * their values while the dialog is closed, until a submission succeeds.
 */
function AppSubmissionDialog({ open, onOpenChange, platforms, types }: AppSubmissionDialogProps) {
  const [sent, setSent] = React.useState(false)
  const form = useForm<Submission>({
    name: '',
    url: '',
    platforms: [],
    uses: [],
    contact: '',
    consent: false,
    icon: null,
  })
  const { data, errors } = form
  // An error about the submission as a whole (the daily limit), which no field shows.
  const [refusal, setRefusal] = React.useState<string[]>()

  const changeOpen = (next: boolean) => {
    if (next) setSent(false)
    onOpenChange(next)
  }

  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    form.transform((fields) => ({ app: fields }))
    setRefusal(undefined)
    form.post(appSubmissions().url, {
      preserveScroll: true,
      onError: (errors) => setRefusal(errors.base),
      onSuccess: () => {
        form.reset()
        setSent(true)
      },
    })
  }

  // Props for a field's input: its error, and the description that names it.
  const field = (name: keyof Submission) => ({
    id: `app-${name}`,
    'aria-invalid': errors[name] ? true : undefined,
    'aria-describedby': errors[name] ? `app-${name}-error` : undefined,
  })

  return (
    <Dialog open={open} onOpenChange={changeOpen}>
      <DialogContent className="max-h-[calc(100dvh-2rem)] overflow-y-auto">
        {sent ? (
          <div role="status" className="flex flex-col items-center gap-2 py-6 text-center">
            <DialogTitle className="text-2xl">Thanks, we have your app</DialogTitle>
            <DialogDescription className="max-w-sm text-pretty">
              The QUL team checks each app before it is listed. We will email you when it is live, or if we have a
              question.
            </DialogDescription>
            <Button className="mt-3" onClick={() => changeOpen(false)}>
              Done
            </Button>
          </div>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle>Submit your app</DialogTitle>
              <DialogDescription>
                Built something with QUL data? Tell us about it and we will add it to the directory.
              </DialogDescription>
            </DialogHeader>
            <GatedForm
              returnTo={appsDirectory({ query: { submit: 1 } }).url}
              purpose="submit your app"
              onSubmit={submit}
            >
              <div className="grid gap-4 sm:grid-cols-2">
                <Field name="name" label="App name" error={errors.name}>
                  <Input
                    {...field('name')}
                    required
                    maxLength={100}
                    placeholder="e.g. Noor Quran"
                    value={data.name}
                    onChange={(event) => form.setData('name', event.target.value)}
                  />
                </Field>
                <Field name="url" label="Link" error={errors.url}>
                  <Input
                    {...field('url')}
                    type="url"
                    required
                    placeholder="Store page, website or repo"
                    value={data.url}
                    onChange={(event) => form.setData('url', event.target.value)}
                  />
                </Field>
              </div>
              <Field name="platforms" label="Platforms" group error={errors.platforms}>
                {platforms.map((platform) => (
                  <FilterChip
                    key={platform.key}
                    option={platform}
                    selected={data.platforms.includes(platform.key)}
                    onClick={() => form.setData('platforms', toggled(data.platforms, platform.key))}
                  />
                ))}
              </Field>
              <Field name="uses" label="Which QUL resources does it use?" group error={errors.uses}>
                {types.map((type) => (
                  <FilterChip
                    key={type.key}
                    option={type}
                    selected={data.uses.includes(type.key)}
                    onClick={() => form.setData('uses', toggled(data.uses, type.key))}
                  />
                ))}
              </Field>
              <Field
                name="icon"
                label="Icon (optional)"
                error={errors.icon}
                hint="PNG, JPEG or WebP, up to 1 MB. Square images look best."
              >
                <Input
                  {...field('icon')}
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  className="py-2"
                  onChange={(event) => form.setData('icon', event.target.files?.[0] ?? null)}
                />
              </Field>
              <Field name="contact" label="Contact email" error={errors.contact} hint="Only the QUL team sees this.">
                <Input
                  {...field('contact')}
                  type="email"
                  required
                  placeholder="you@example.com"
                  value={data.contact}
                  onChange={(event) => form.setData('contact', event.target.value)}
                />
              </Field>
              <div className="flex flex-col gap-2">
                <Label className="items-start gap-3 rounded-lg bg-secondary p-4 leading-snug font-normal">
                  <Checkbox
                    {...field('consent')}
                    className="mt-0.5"
                    checked={data.consent}
                    onCheckedChange={(checked) => form.setData('consent', checked === true)}
                  />
                  <span>QUL may list and feature this app on qul.tarteel.ai, with its name, description and link.</span>
                </Label>
                <FieldError name="consent" error={errors.consent} />
              </div>
              {refusal && (
                <p role="alert" className="rounded-lg bg-destructive/10 p-4 text-sm text-destructive">
                  {refusal.join(' ')}
                </p>
              )}
              <DialogFooter>
                <Button type="button" variant="ghost" onClick={() => changeOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={form.processing}>
                  Submit app
                </Button>
              </DialogFooter>
            </GatedForm>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}

/**
 * A labelled field with its hint and server error. A `group` field is a set of chips, named by
 * the label; otherwise the label names the input with the id `app-<name>`.
 */
function Field({
  name,
  label,
  group = false,
  error,
  hint,
  children,
}: {
  name: keyof Submission
  label: string
  group?: boolean
  error?: string[]
  hint?: string
  children: React.ReactNode
}) {
  return (
    <div className="flex flex-col gap-2">
      {group ? (
        <>
          <span id={`app-${name}-label`} className="text-sm leading-none font-medium">
            {label}
          </span>
          <div
            role="group"
            aria-labelledby={`app-${name}-label`}
            aria-describedby={error ? `app-${name}-error` : undefined}
            className="flex flex-wrap gap-1.5"
          >
            {children}
          </div>
        </>
      ) : (
        <>
          <Label htmlFor={`app-${name}`}>{label}</Label>
          {children}
        </>
      )}
      {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
      <FieldError name={name} error={error} />
    </div>
  )
}

function FieldError({ name, error }: { name: keyof Submission; error?: string[] }) {
  if (!error) return null
  return (
    <p id={`app-${name}-error`} className="text-sm text-destructive">
      {error.join(' ')}
    </p>
  )
}

export { AppSubmissionDialog }

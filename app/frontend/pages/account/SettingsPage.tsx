import { useForm, usePage } from '@inertiajs/react'
import { EyeIcon, EyeOffIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Label, Textarea } from '@/components/ui/input'
import { profile } from '@/routes'
import type { AccountProfilesEdit } from '@/types/serializers'

/** A labelled field with its hint and its errors, which the control names as its description. */
function Field({
  id,
  label,
  hint,
  errors,
  children,
}: {
  id: string
  label: string
  hint?: string
  errors?: string[]
  children: (control: { id: string; 'aria-invalid'?: true; 'aria-describedby'?: string }) => React.ReactNode
}) {
  const describedBy = [errors && `${id}-error`, hint && `${id}-hint`].filter(Boolean).join(' ')
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={id}>{label}</Label>
      {children({ id, 'aria-invalid': errors ? true : undefined, 'aria-describedby': describedBy || undefined })}
      {hint && (
        <p id={`${id}-hint`} className="text-sm text-muted-foreground">
          {hint}
        </p>
      )}
      {errors && (
        <p id={`${id}-error`} role="alert" className="text-sm text-error">
          {errors.join(' ')}
        </p>
      )}
    </div>
  )
}

/** A password field with a button that shows what was typed. */
function PasswordInput(props: Omit<React.ComponentProps<typeof Input>, 'type'>) {
  const [shown, setShown] = React.useState(false)
  return (
    <div className="relative">
      <Input type={shown ? 'text' : 'password'} className="pe-11" {...props} />
      <button
        type="button"
        onClick={() => setShown(!shown)}
        aria-label={shown ? 'Hide the password' : 'Show the password'}
        aria-pressed={shown}
        className="absolute inset-y-0 end-0 flex w-10 items-center justify-center rounded-e-lg text-muted-foreground outline-none hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 [&_svg]:size-4"
      >
        {shown ? <EyeOffIcon /> : <EyeIcon />}
      </button>
    </div>
  )
}

// Both forms send PATCH /profile, which goes to the profile with a notice when the change is
// saved and comes back here with the errors when it is not.
const SAVE = { preserveScroll: 'errors' } as const

function ProfileForm({ firstName, lastName, about }: AccountProfilesEdit) {
  const form = useForm({ first_name: firstName, last_name: lastName, about_me: about })
  const { data, errors } = form
  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    form.transform((fields) => ({ user: fields }))
    form.patch(profile().url, SAVE)
  }

  return (
    <form onSubmit={submit}>
      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardDescription>Your name is shown on your profile and in the header.</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          <div className="grid gap-5 sm:grid-cols-2">
            <Field id="settings-first-name" label="First name" errors={errors.first_name}>
              {(control) => (
                <Input
                  {...control}
                  required
                  maxLength={50}
                  autoComplete="given-name"
                  value={data.first_name}
                  onChange={(event) => form.setData('first_name', event.target.value)}
                />
              )}
            </Field>
            <Field id="settings-last-name" label="Last name" errors={errors.last_name}>
              {(control) => (
                <Input
                  {...control}
                  required
                  maxLength={50}
                  autoComplete="family-name"
                  value={data.last_name}
                  onChange={(event) => form.setData('last_name', event.target.value)}
                />
              )}
            </Field>
          </div>
          <Field
            id="settings-about"
            label="About me"
            hint="Only you and the QUL team can see this."
            errors={errors.about_me}
          >
            {(control) => (
              <Textarea
                {...control}
                rows={5}
                value={data.about_me}
                onChange={(event) => form.setData('about_me', event.target.value)}
              />
            )}
          </Field>
        </CardContent>
        <CardFooter>
          <Button type="submit" disabled={form.processing}>
            Save profile
          </Button>
        </CardFooter>
      </Card>
    </form>
  )
}

function SignInForm({ email, emailStatus, unconfirmedEmail }: AccountProfilesEdit) {
  const form = useForm({ email, password: '', password_confirmation: '', current_password: '' })
  const { data, errors } = form
  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    form.transform((fields) => ({ user: fields }))
    form.patch(profile().url, SAVE)
  }
  // The server asks for the current password only when the email or the password changes.
  const changes = data.email !== email || data.password !== ''

  return (
    <form onSubmit={submit}>
      <Card>
        <CardHeader>
          <CardTitle>Email and password</CardTitle>
          <CardDescription>What you sign in with. A change needs your current password.</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          <Field
            id="settings-email"
            label="Email"
            hint={unconfirmedEmail ? `Waiting for you to verify ${unconfirmedEmail}.` : undefined}
            errors={errors.email}
          >
            {(control) => (
              <div className="flex items-center gap-3">
                <Input
                  {...control}
                  type="email"
                  required
                  autoComplete="email"
                  value={data.email}
                  onChange={(event) => form.setData('email', event.target.value)}
                />
                {emailStatus === 'confirmed' && <Badge variant="success">Verified</Badge>}
                {emailStatus === 'pending' && <Badge variant="warning">Change pending</Badge>}
                {emailStatus === 'unconfirmed' && <Badge variant="warning">Unverified</Badge>}
              </div>
            )}
          </Field>
          <Field id="settings-current-password" label="Current password" errors={errors.current_password}>
            {(control) => (
              <PasswordInput
                {...control}
                required={changes}
                autoComplete="current-password"
                value={data.current_password}
                onChange={(event) => form.setData('current_password', event.target.value)}
              />
            )}
          </Field>
          <div className="grid gap-5 sm:grid-cols-2">
            <Field
              id="settings-password"
              label="New password"
              hint="6 to 128 characters. Leave empty to keep your password."
              errors={errors.password}
            >
              {(control) => (
                <PasswordInput
                  {...control}
                  autoComplete="new-password"
                  value={data.password}
                  onChange={(event) => form.setData('password', event.target.value)}
                />
              )}
            </Field>
            <Field
              id="settings-password-confirmation"
              label="Confirm new password"
              errors={errors.password_confirmation}
            >
              {(control) => (
                <PasswordInput
                  {...control}
                  autoComplete="new-password"
                  value={data.password_confirmation}
                  onChange={(event) => form.setData('password_confirmation', event.target.value)}
                />
              )}
            </Field>
          </div>
        </CardContent>
        <CardFooter>
          <Button type="submit" disabled={form.processing || !changes}>
            Save email and password
          </Button>
        </CardFooter>
      </Card>
    </form>
  )
}

// /profile/edit: the account settings, as two forms that save on their own. The profile form
// changes the name and the "about me" text; the other changes what the user signs in with.
export default function SettingsPage(props: AccountProfilesEdit) {
  const { nav } = usePage().props

  return (
    <SiteShell>
      <Container className="max-w-4xl pt-12 pb-16">
        <PageHeader
          breadcrumb={[{ label: nav.profile.label, href: nav.profile.href }, { label: 'Account settings' }]}
          title="Account settings"
          description={`Member since ${props.memberSince}.`}
        />
        <div className="mt-8 flex flex-col gap-6">
          <ProfileForm {...props} />
          <SignInForm {...props} />
        </div>
      </Container>
    </SiteShell>
  )
}

import { usePage } from '@inertiajs/react'
import type * as React from 'react'

import { cn } from '@/lib/utils'
import { newUserSession } from '@/routes'

export interface GatedFormProps extends React.ComponentProps<'form'> {
  /** A URL that shows this form open: sign-in comes back to it. */
  returnTo: string
  /** What signing in lets the visitor do, after "Sign in to", e.g. "submit your app". */
  purpose: string
}

/**
 * A form only a signed-in visitor can send. The `auth` shared prop decides: a signed-out
 * visitor sees every field, disabled, under a sign-in link that comes back to `returnTo`. The
 * server refuses an anonymous submit whatever the page shows.
 */
function GatedForm({ returnTo, purpose, className, children, ...props }: GatedFormProps) {
  const signedIn = usePage().props.auth.user !== null

  return (
    <form className={cn('flex flex-col gap-5', className)} {...props}>
      {!signedIn && (
        <p className="rounded-lg border bg-secondary p-4 text-sm">
          <a
            href={newUserSession({ query: { user_return_to: returnTo } }).url}
            className="font-medium underline underline-offset-4"
          >
            Sign in
          </a>{' '}
          to {purpose}. After you sign in, this form opens again.
        </p>
      )}
      <fieldset disabled={!signedIn} className="contents">
        {children}
      </fieldset>
    </form>
  )
}

export { GatedForm }

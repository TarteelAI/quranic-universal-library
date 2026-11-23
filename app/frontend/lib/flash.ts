import { usePage } from '@inertiajs/react'
import { useEffect } from 'react'
import { toast } from 'sonner'

// Shows the Rails flash (`notice` and `alert`) of the current page as toasts: on the page a
// redirect lands on, after a full load or an Inertia visit. A history entry keeps no flash, so
// Back shows none. The fixed ids make a second call for the same flash (StrictMode, a deferred
// props response) update the toast in place.
export function useFlashToasts() {
  const { flash } = usePage()

  useEffect(() => {
    if (flash.notice) toast.success(flash.notice, { id: 'flash-notice' })
    if (flash.alert) toast.error(flash.alert, { id: 'flash-alert' })
  }, [flash])
}

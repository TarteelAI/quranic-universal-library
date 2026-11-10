import * as React from 'react'

import { cn } from '@/lib/utils'

import type ShardRingRenderer from './shards/renderer'

let webGL: boolean | undefined

function supportsWebGL() {
  if (webGL === undefined) {
    try {
      const canvas = document.createElement('canvas')
      webGL = !!(window.WebGLRenderingContext && (canvas.getContext('webgl2') || canvas.getContext('webgl')))
    } catch {
      webGL = false
    }
  }
  return webGL
}

const unchanging = () => () => {}

type Motion = 'pending' | 'running' | 'still' | 'fallback'

export interface ShardRingProps {
  className?: string
  /** The still image shown without WebGL. */
  fallbackSrc?: string
}

/**
 * QUL's animated shard ring, the WebGL scene of the old landing page. It draws on its own
 * near-black background, so place it on a dark surface. The renderer is loaded once the ring is
 * on screen, and not at all without WebGL, where a still image shows instead. Under reduced
 * motion it draws one frame; otherwise it animates while on screen and the tab is visible.
 * `data-motion` says which of these applies.
 */
function ShardRing({ className, fallbackSrc = '/shards.webp' }: ShardRingProps) {
  const rootRef = React.useRef<HTMLDivElement>(null)
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  // The server renders the canvas; the browser swaps in the image right after hydration when
  // it has no WebGL.
  const webGL = React.useSyncExternalStore(unchanging, supportsWebGL, () => true)
  const [state, setState] = React.useState<Motion>('pending')
  const motion = webGL ? state : 'fallback'

  React.useEffect(() => {
    const root = rootRef.current
    const canvas = canvasRef.current
    // Hydration renders with the server's value, so ask the browser itself.
    if (!supportsWebGL() || !root || !canvas) return

    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let ring: ShardRingRenderer | null = null
    let loading: Promise<void> | null = null
    let disposed = false
    let visible = false

    const resume = () => {
      if (!ring) return
      if (still) ring.renderStill()
      else if (!document.hidden) ring.start()
    }
    const load = () =>
      import('./shards/renderer')
        .then(({ default: Renderer }) => {
          if (disposed) return
          ring = new Renderer(canvas, root)
          setState(still ? 'still' : 'running')
          if (visible) resume()
        })
        .catch((error: unknown) => {
          console.error('[shards] failed to initialise', error)
          setState('fallback')
        })

    const observer = new IntersectionObserver(
      (entries) => {
        visible = entries.some((entry) => entry.isIntersecting)
        if (visible) {
          loading ??= load()
          resume()
        } else ring?.stop()
      },
      { threshold: 0.05 },
    )
    observer.observe(root)
    const onVisibility = () => {
      if (document.hidden) ring?.stop()
      else if (visible) resume()
    }
    document.addEventListener('visibilitychange', onVisibility)

    return () => {
      disposed = true
      observer.disconnect()
      document.removeEventListener('visibilitychange', onVisibility)
      ring?.dispose()
    }
  }, [])

  return (
    <div ref={rootRef} data-motion={motion} className={cn('relative overflow-hidden', className)}>
      {motion === 'fallback' ? (
        <img src={fallbackSrc} alt="" className="size-full object-cover" />
      ) : (
        <canvas ref={canvasRef} className="block size-full" aria-hidden="true" />
      )}
    </div>
  )
}

export { ShardRing }

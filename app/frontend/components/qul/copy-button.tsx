import { CheckIcon, CopyIcon } from 'lucide-react'
import { useEffect, useState } from 'react'

import { Button } from '@/components/ui/button'

// Copies `text()` to the clipboard and says so for a moment. `label` names what it copies for
// screen readers ("Copy code", "Copy link").
export function CopyButton({ text, label = 'Copy code' }: { text: () => string; label?: string }) {
  const [copied, setCopied] = useState(false)
  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), 1500)
    return () => clearTimeout(timer)
  }, [copied])

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => navigator.clipboard.writeText(text()).then(() => setCopied(true))}
      aria-label={copied ? 'Copied' : label}
    >
      {copied ? <CheckIcon /> : <CopyIcon />}
      {copied ? 'Copied' : 'Copy'}
    </Button>
  )
}

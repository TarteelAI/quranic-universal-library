import { FileIcon, UploadIcon, XIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { formatBytes } from '@/lib/format'
import { cn } from '@/lib/utils'

export interface FileDropProps {
  id: string
  files: File[]
  onChange: (files: File[]) => void
  /** The `accept` list of the file input. */
  accept?: string
  maxFiles: number
  maxSize: number
  /** What the zone takes, under its prompt. */
  hint: string
  'aria-describedby'?: string
  'aria-invalid'?: boolean
}

/**
 * A drop zone for several files: drop them on it or press it to choose, then see each one's name
 * and size with a button that removes it. Files past `maxFiles` or over `maxSize` are left out with
 * a message; the server checks the files again. Inside a disabled fieldset the input is disabled.
 */
export function FileDrop({ id, files, onChange, accept, maxFiles, maxSize, hint, ...aria }: FileDropProps) {
  const [over, setOver] = React.useState(false)
  const [refused, setRefused] = React.useState<string>()

  const add = (chosen: File[]) => {
    const fitting = chosen.filter((file) => file.size <= maxSize)
    const next = [...files, ...fitting].slice(0, maxFiles)
    const left = chosen.length - (next.length - files.length)
    setRefused(
      left > 0
        ? `${left === 1 ? 'One file was' : `${left} files were`} left out: at most ${maxFiles} files, each up to ${formatBytes(maxSize)}.`
        : undefined,
    )
    onChange(next)
  }

  const drop = (event: React.DragEvent) => {
    event.preventDefault()
    setOver(false)
    add(Array.from(event.dataTransfer.files))
  }

  return (
    <div className="flex flex-col gap-2">
      <label
        htmlFor={id}
        onDragOver={(event) => {
          event.preventDefault()
          setOver(true)
        }}
        onDragLeave={() => setOver(false)}
        onDrop={drop}
        className={cn(
          'flex cursor-pointer flex-col items-center gap-1 rounded-lg border border-dashed border-input px-4 py-5 text-center text-sm transition-colors',
          'hover:bg-accent/50 has-[:focus-visible]:ring-[3px] has-[:focus-visible]:ring-ring/50 has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-50',
          over && 'border-primary bg-accent/50',
        )}
      >
        <UploadIcon className="size-5 text-muted-foreground" aria-hidden="true" />
        <span className="font-medium">Drop files here or choose them</span>
        <span className="text-muted-foreground">{hint}</span>
        <input
          id={id}
          type="file"
          multiple
          accept={accept}
          className="sr-only"
          {...aria}
          onChange={(event) => {
            add(Array.from(event.target.files ?? []))
            event.target.value = ''
          }}
        />
      </label>
      {refused && (
        <p className="text-sm text-destructive" aria-live="polite">
          {refused}
        </p>
      )}
      {files.length > 0 && (
        <ul aria-label="Chosen files" className="flex flex-col gap-1">
          {files.map((file, index) => (
            <li
              key={`${file.name}-${index}`}
              className="flex items-center gap-2 rounded-md bg-secondary py-1 pr-1 pl-3 text-sm"
            >
              <FileIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
              <span className="min-w-0 flex-1 truncate">{file.name}</span>
              <span className="shrink-0 text-muted-foreground tabular-nums">{formatBytes(file.size)}</span>
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                aria-label={`Remove ${file.name}`}
                onClick={() => {
                  setRefused(undefined)
                  onChange(files.filter((_, at) => at !== index))
                }}
              >
                <XIcon />
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

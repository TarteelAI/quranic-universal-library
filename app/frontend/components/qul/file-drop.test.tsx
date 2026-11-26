import { fireEvent, render, screen, within } from '@testing-library/react'
import * as React from 'react'
import { describe, expect, it } from 'vitest'

import { FileDrop } from './file-drop'

function file(name: string, size: number) {
  return new File([new Uint8Array(size)], name)
}

function Zone({ maxFiles = 3 }: { maxFiles?: number }) {
  const [files, setFiles] = React.useState<File[]>([])
  return (
    <>
      <label htmlFor="files">Source files</label>
      <FileDrop id="files" files={files} onChange={setFiles} maxFiles={maxFiles} maxSize={2048} hint="PDF files" />
    </>
  )
}

describe('FileDrop', () => {
  it('lists the chosen files with their sizes, and removes one', () => {
    render(<Zone />)

    fireEvent.change(screen.getByLabelText('Source files'), {
      target: { files: [file('tafsir.pdf', 1024), file('notes.txt', 10)] },
    })

    const list = within(screen.getByRole('list', { name: 'Chosen files' }))
    expect(list.getAllByRole('listitem').map((item) => item.textContent)).toEqual([
      'tafsir.pdf1 KB',
      'notes.txt10 bytes',
    ])
    fireEvent.click(list.getByRole('button', { name: 'Remove tafsir.pdf' }))
    expect(screen.getByRole('list', { name: 'Chosen files' }).textContent).toBe('notes.txt10 bytes')
  })

  it('takes dropped files, and leaves out files over the size or past the count with a message', () => {
    render(<Zone maxFiles={2} />)

    fireEvent.drop(screen.getByText('Drop files here or choose them'), {
      dataTransfer: { files: [file('a.pdf', 10), file('big.pdf', 4096), file('b.pdf', 10), file('c.pdf', 10)] },
    })

    expect(screen.getByRole('list', { name: 'Chosen files' }).textContent).toBe('a.pdf10 bytesb.pdf10 bytes')
    expect(screen.getByText('2 files were left out: at most 2 files, each up to 2 KB.')).toBeDefined()
  })
})

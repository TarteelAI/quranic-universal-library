// The zip is built with Node's streams: jsdom's globals and Node's do not mix.
// @vitest-environment node
import { afterEach, describe, expect, it, vi } from 'vitest'

import type { CatalogBundleItem } from '@/types/serializers'

import { readme, totalBytes, zipEntries, zipName, zipStream } from './zip-download'

const file = (id: number, format: 'json' | 'sqlite', filename: string, byteSize = 100) => ({
  id,
  name: format,
  filename,
  format,
  formatLabel: format.toUpperCase(),
  byteSize,
  md5: 'abc',
})

const translation: CatalogBundleItem = {
  id: 1,
  restricted: false,
  resource: { id: 1, name: 'Saheeh International', type: 'translation', toParam: 'saheeh-international' },
  category: 'translation',
  files: [file(11, 'json', 'en-sahih.json.zip'), file(12, 'sqlite', 'en-sahih.db.zip', 300)],
  licence: { name: 'CC BY 4.0', url: 'https://creativecommons.org/licenses/by/4.0/', summary: null },
}
const restricted: CatalogBundleItem = {
  id: 2,
  restricted: true,
  resource: { id: 2, name: 'Closed tafsir', type: 'tafsir', toParam: 'closed' },
  category: 'tafsir',
  files: [],
  licence: null,
}
const gone: CatalogBundleItem = { id: 3, restricted: false, resource: null, category: null, files: [], licence: null }

afterEach(() => vi.unstubAllGlobals())

describe('zipEntries', () => {
  it('puts each file of a downloadable resource under <type>/<slug>/, fetched from its download URL', () => {
    const entries = zipEntries([translation, restricted, gone])

    expect(entries.map(({ path, url, byteSize }) => ({ path, url, byteSize }))).toEqual([
      {
        path: 'translation/saheeh-international/en-sahih.json.zip',
        url: '/resources/translation/saheeh-international/download/11',
        byteSize: 100,
      },
      {
        path: 'translation/saheeh-international/en-sahih.db.zip',
        url: '/resources/translation/saheeh-international/download/12',
        byteSize: 300,
      },
    ])
    expect(totalBytes(entries)).toBe(400)
  })

  it("keeps the formats asked for where a resource has them, and gives a repeated name the file's id", () => {
    expect(zipEntries([translation], ['sqlite']).map((entry) => entry.path)).toEqual([
      'translation/saheeh-international/en-sahih.db.zip',
    ])
    expect(zipEntries([translation], ['font'])).toHaveLength(2)

    const twice = { ...translation, files: [file(11, 'json', 'a.zip'), file(12, 'json', 'a.zip')] }
    expect(zipEntries([twice]).map((entry) => entry.path)).toEqual([
      'translation/saheeh-international/a.zip',
      'translation/saheeh-international/12-a.zip',
    ])
  })
})

describe('zipName', () => {
  it.each([
    ['Recitation with highlighting', 'recitation-with-highlighting.zip'],
    ['IndoPak reader with Urdu and English', 'indopak-reader-with-urdu-and-english.zip'],
    ['QUL bundle', 'qul-bundle.zip'],
    ['!!', 'qul.zip'],
  ])('%s is saved as %s', (title, name) => {
    expect(zipName(title)).toBe(name)
  })
})

describe('readme', () => {
  it('names each resource with its page, licence and files, then what is not included', () => {
    const entries = zipEntries([translation])
    const text = readme('Recitation kit', 'https://qul.tarteel.ai', [translation, restricted, gone], entries, [
      { path: entries[1].path, reason: 'no longer available' },
    ])

    expect(text).toBe(
      [
        '# Recitation kit',
        '',
        'Downloaded from the Quranic Universal Library (QUL), https://qul.tarteel.ai.',
        '',
        '## Saheeh International',
        '',
        '- Page: https://qul.tarteel.ai/resources/translation/saheeh-international',
        '- Licence: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)',
        '- `translation/saheeh-international/en-sahih.json.zip` (100 bytes)',
        '',
        '## Not included',
        '',
        '- Closed tafsir: the publisher does not allow downloads.',
        '- Resource 3: no longer in the library.',
        '- `translation/saheeh-international/en-sahih.db.zip`: no longer available',
        '',
      ].join('\n'),
    )
  })
})

describe('zipStream', () => {
  it('fetches each file in turn, leaves out the ones that fail and names them in the README', async () => {
    const fetchMock = vi.fn((url: string) =>
      Promise.resolve(
        url.endsWith('/11')
          ? new Response('JSON-BYTES', { headers: { 'Content-Type': 'application/zip' } })
          : new Response('<html>Sign in</html>', { headers: { 'Content-Type': 'text/html; charset=utf-8' } }),
      ),
    )
    vi.stubGlobal('fetch', fetchMock)
    const progress = vi.fn()
    const entries = zipEntries([translation])

    const { stream, failed } = await zipStream({
      title: 'Kit',
      origin: 'https://qul.tarteel.ai',
      items: [translation],
      entries,
      signal: new AbortController().signal,
      onProgress: progress,
    })
    const bytes = new Uint8Array(await new Response(stream).arrayBuffer())
    const text = new TextDecoder().decode(bytes)

    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([entries[0].url, entries[1].url])
    expect(failed).toEqual([{ path: entries[1].path, reason: 'sign in to download' }])
    // Stored, not compressed: the names and contents are in the zip as they are.
    expect(text).toContain('translation/saheeh-international/en-sahih.json.zip')
    expect(text).toContain('JSON-BYTES')
    expect(text).not.toContain('<html>')
    expect(text).toContain('README.md')
    expect(text).toContain('- `translation/saheeh-international/en-sahih.db.zip`: sign in to download')
    expect(progress).toHaveBeenLastCalledWith({ files: 2, bytes: 10 })
  })

  it('gives a refused file a neutral reason, since storage answers 403 too', async () => {
    vi.stubGlobal('fetch', () => Promise.resolve(new Response('denied', { status: 403 })))
    const entries = zipEntries([translation]).slice(0, 1)

    const { stream, failed } = await zipStream({
      title: 'Kit',
      origin: 'https://qul.tarteel.ai',
      items: [translation],
      entries,
      signal: new AbortController().signal,
      onProgress: () => {},
    })
    await new Response(stream).arrayBuffer()

    expect(failed).toEqual([{ path: entries[0].path, reason: 'the server refused the download' }])
  })

  it('stops when the signal aborts', async () => {
    const abort = new AbortController()
    vi.stubGlobal(
      'fetch',
      vi.fn(() => {
        abort.abort()
        return Promise.reject(new DOMException('Aborted', 'AbortError'))
      }),
    )
    const { stream } = await zipStream({
      title: 'Kit',
      origin: 'https://qul.tarteel.ai',
      items: [translation],
      entries: zipEntries([translation]),
      signal: abort.signal,
      onProgress: () => {},
    })

    await expect(new Response(stream).arrayBuffer()).rejects.toThrow()
  })
})

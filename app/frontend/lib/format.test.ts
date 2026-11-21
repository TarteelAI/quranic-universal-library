import { describe, expect, it } from 'vitest'

import { formatBytes, plainText } from './format'

describe('formatBytes', () => {
  it.each([
    [0, '0 bytes'],
    [1, '1 byte'],
    [1023, '1023 bytes'],
    [1024, '1 KB'],
    [1536, '1.5 KB'],
    [1_048_575, '1 MB'],
    [5_347_738, '5.1 MB'],
    [626_275_670, '597.3 MB'],
    [3_221_225_472, '3 GB'],
  ])('%i bytes reads as %s', (bytes, label) => {
    expect(formatBytes(bytes)).toBe(label)
  })
})

describe('plainText', () => {
  it('keeps the text of tajweed markup and drops its tags', () => {
    expect(plainText('<rule class="ham_wasl">ٱ</rule>للَّهِ <rule class="madda_normal">مَا</rule>')).toBe('ٱللَّهِ مَا')
  })

  it('leaves text without markup as it is', () => {
    expect(plainText('بِسْمِ ٱللَّهِ')).toBe('بِسْمِ ٱللَّهِ')
  })

  it('never leaves an angle bracket behind, from nested, broken or unclosed tags', () => {
    expect(plainText('a<<b>>c')).toBe('ac')
    expect(plainText('a<scr<b>ipt>c')).toBe('aiptc')
    expect(plainText('a<b')).toBe('a')
    expect(plainText('a>b')).toBe('ab')
  })
})

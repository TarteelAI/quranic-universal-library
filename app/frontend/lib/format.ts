const UNITS = ['KB', 'MB', 'GB', 'TB']

// A byte count as people read it: 1024 bytes to the kilobyte, at most one decimal.
export function formatBytes(bytes: number) {
  if (bytes < 1024) return bytes === 1 ? '1 byte' : `${bytes} bytes`

  let value = bytes / 1024
  let unit = 0
  while (Number(value.toFixed(1)) >= 1024 && unit < UNITS.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${Number(value.toFixed(1))} ${UNITS[unit]}`
}

// The characters of marked-up text (tajweed <rule> tags) without the markup: everything from a
// "<" to the next ">" is dropped, so no angle bracket is ever left in the result.
export function plainText(html: string) {
  let text = ''
  let inTag = false
  for (const char of html) {
    if (char === '<') inTag = true
    else if (char === '>') inTag = false
    else if (!inTag) text += char
  }
  return text
}

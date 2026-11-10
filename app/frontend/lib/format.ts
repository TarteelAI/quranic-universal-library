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

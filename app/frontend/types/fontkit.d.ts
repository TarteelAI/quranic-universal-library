// The parts of fontkit 2 (it ships no types) that the glyph view uses.
declare module 'fontkit' {
  export interface BBox {
    minX: number
    minY: number
    maxX: number
    maxY: number
  }

  export interface Path {
    bbox: BBox
    toSVG(): string
  }

  export interface Glyph {
    id: number
    name: string | null
    path: Path
    bbox: BBox
  }

  export interface Font {
    numGlyphs: number
    characterSet: number[]
    unitsPerEm: number
    glyphForCodePoint(codePoint: number): Glyph | null
    getGlyph(id: number): Glyph | null
  }

  export function create(buffer: Uint8Array): Font
}
